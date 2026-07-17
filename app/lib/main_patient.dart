import 'package:account/account.dart'
    show buildAccountAdapter, DeniedCountriesPort, deniedCountriesPortProvider;
import 'package:auth/auth.dart' show UserSignedIn, UserSignedOut;
import 'package:core/core.dart';
import 'package:emergency_card/emergency_card.dart'
    show
        EmergencyCardSnapshot,
        EmergencySnapshotReader,
        emergencySnapshotReaderProvider;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geofence_block/geofence_block.dart'
    show ReadDeniedCountriesRepository, deniedCountriesRepositoryProvider;
import 'package:profile/profile.dart' show EmergencyContact, profileDaoProvider;
import 'patient_app/app_state.dart';
import 'patient_app/prefs.dart';
import 'patient_app/shell.dart';

/// In-session holder for the signed-in user id. `currentUserIdProvider` reads
/// this, so an in-session sign-in / sign-out is reflected immediately (the
/// boot-time secure-storage value only seeds it). Updated by the
/// UserSignedIn / UserSignedOut bus listeners in [main].
final _sessionUserIdProvider = StateProvider<UserId?>((ref) => null);

/// Entrypoint for the claude.ai/design "Patient App" Flutter port.
/// Restores the persisted session so a signed-in user skips the auth flow.
/// Run: flutter run -t lib/main_patient.dart --flavor dev \
///        --dart-define-from-file=env/balsm/dev.json \
///        --dart-define-from-file=env/shared.json
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlavorConfig.initFromEnvironment();

  // Telemetry: crash reporting + user-action analytics via the AnalyticsLogger
  // facade (Sentry backend). See docs/superpowers/specs/2026-07-03-telemetry-*.
  await initSentry();
  // Global KV store (shared_preferences behind the interface) — the only
  // place that constructs it; everything else sees KeyValueDataSource.
  final globalKV = await SharedPrefsKVDataSource.create();

  // On-device encrypted PHI database (opened once, injected as a value).
  final db = await AppDatabase.open();
  // Current authenticated user id (opaque, non-PHI), if signed in. Read from
  // the platform secure store before the container is built.
  const secureStorage = FlutterSecureStorage();
  final userId = await secureStorage.read(key: 'balsm.user_id');

  final container = ProviderContainer(overrides: [
    analyticsLoggerProvider.overrideWithValue(const SentryAnalyticsLogger()),
    // Bind the account module's adapter into core's cross-module read port so
    // other modules (e.g. home) read the account summary without importing it.
    readAccountRepositoryProvider.overrideWith(buildAccountAdapter),
    globalKVDataSourceProvider.overrideWithValue(globalKV),
    // ── Real P001 module provider seams (recovered from bootstrap.dart) ─────
    appDatabaseProvider.overrideWithValue(db),
    // Reactive: reads the in-session holder (seeded from storage below), so
    // sign-in/out updates every PHI reader without an app restart.
    currentUserIdProvider.overrideWith((ref) => ref.watch(_sessionUserIdProvider)),
    // Flutter-side API controller owns the shared BalsmApiClient; the derived
    // balsmApiClientProvider reads `.client` off it.
    balsmApiControllerProvider.overrideWith(
      (ref) => BalsmApiController.create(
        storage: const FlutterSecureStorage(),
        bus: ref.watch(eventBusProvider),
      ),
    ),
    secureStorageProvider.overrideWithValue(SecureStorageWrapper()),
    // Emergency card reads the on-device HealthProfile (PHI stays on-device).
    emergencySnapshotReaderProvider.overrideWith(
      (ref) => _ProfileEmergencySnapshotReader(ref),
    ),
    // Account country-change consults the geofence denied-countries repo.
    deniedCountriesPortProvider.overrideWith(
      (ref) => _GeofenceDeniedCountriesPort(
        ref.watch(deniedCountriesRepositoryProvider),
      ),
    ),
    // ── Encrypted offline backup/sync (PHI → user's own cloud) ──────────────
    // Google Drive on both platforms (iCloud adapter deferred). The blob is
    // keyed to the signed-in user; 'local' when signed out.
    backupServiceProvider.overrideWith((ref) {
      final service = BackupService(
        bus: ref.watch(eventBusProvider),
        snapshot: ref.watch(snapshotServiceProvider),
        adapter: DriveBackupAdapter(),
        storage: ref.watch(secureStorageProvider),
        status: ref.watch(syncStatusProvider.notifier),
        userId: ref.watch(currentUserIdProvider)?.value ?? 'local',
        onlineStream: connectivityOnlineStream(),
      );
      ref.onDispose(service.dispose);
      return service;
    }),
    restoreServiceProvider.overrideWith((ref) => RestoreService(
          adapter: DriveBackupAdapter(),
          snapshot: ref.watch(snapshotServiceProvider),
          storage: ref.watch(secureStorageProvider),
          userId: ref.watch(currentUserIdProvider)?.value ?? 'local',
        )),
  ]);
  final analytics = container.read(analyticsLoggerProvider);

  // Every framework error → telemetry (still shown in debug console).
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    analytics.logError(
      details.exception,
      stackTrace: details.stack,
      message: details.context?.toString(),
    );
  };
  // Every uncaught async / platform error → telemetry (fatal).
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    analytics.logError(error, stackTrace: stack, fatal: true);
    return true;
  };

  // Every domain AppEvent published on the bus → analytics event/breadcrumb.
  EventBusAnalyticsForwarder(
    bus: container.read(eventBusProvider),
    analytics: analytics,
  ).start();

  // Seed the in-session user id from the boot-time secure-storage value.
  container.read(_sessionUserIdProvider.notifier).state =
      UserId.fromString(userId);

  // Keep the in-session user id live: sign-in sets it, sign-out clears it, so
  // every PHI reader (profile/meds/emergency/backup) sees the current user
  // without an app restart.
  container.read(eventBusProvider).on<UserSignedIn>().listen((e) {
    container.read(_sessionUserIdProvider.notifier).state = e.userId;
  });
  container.read(eventBusProvider).on<UserSignedOut>().listen((_) {
    container.read(_sessionUserIdProvider.notifier).state = null;
  });

  // T173: country change → refresh locale-derived state. Re-fetches the
  // account summary so greeting/locale-dependent reads reflect the change.
  // App-lifetime subscription, mirrors the forwarder above.
  container.read(eventBusProvider).on<CountryChanged>().listen((_) {
    container.invalidate(accountSummaryProvider);
  });

  // Apply the persisted server preset BEFORE the first API call: init() reads
  // the saved preset (`saved ?? defaultServer`) and sets the client base URL.
  // Without this the dev server-selector choice (Local / Staging) is dropped on
  // every relaunch and the app silently reverts to the default server. Must run
  // before runApp — no API request is issued before this point.
  await container.read(balsmApiControllerProvider).init();

  // Migrate the app-shell preference group before its first read.
  final paPrefs = PatientAppPrefs(globalKV);
  await paPrefs.migrate();

  // A dead API session (token refresh failed) — the transport has already
  // cleared the stored tokens; mirror that in-app: drop the in-session user id
  // so every PHI reader goes null, and persist signed-out so the shell returns
  // to the auth flow on next resolution / relaunch.
  container.read(eventBusProvider).on<SessionExpired>().listen((_) {
    container.read(_sessionUserIdProvider.notifier).state = null;
    paPrefs.setSignedIn(false);
  });

  final state = await PatientAppState.load(paPrefs);
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: PatientApp(
        state: state,
        navObserver: AnalyticsRouteObserver(analytics),
      ),
    ),
  );
}

/// Adapts the `profile` package's on-device DAO into the `emergency_card`
/// [EmergencySnapshotReader] port. PHI never leaves the device here.
class _ProfileEmergencySnapshotReader implements EmergencySnapshotReader {
  _ProfileEmergencySnapshotReader(this._ref);

  final Ref _ref;

  @override
  Future<EmergencyCardSnapshot?> readSnapshot() async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return null;
    final profile = await _ref.read(profileDaoProvider).getProfile(userId);
    if (profile == null) return null;

    final primary = profile.emergencyContacts
        .where((c) => c.isPrimary)
        .cast<EmergencyContact?>()
        .firstWhere((_) => true, orElse: () => null);

    return EmergencyCardSnapshot(
      bloodType: profile.bloodType,
      allergyNames: profile.allergies.map((a) => a.name).toList(),
      conditionNames: profile.conditions.map((c) => c.name).toList(),
      primaryContact:
          primary == null ? null : (name: primary.name, phone: primary.phone),
      createdAt: DateTime.now(),
    );
  }
}

/// Adapts `geofence_block`'s [ReadDeniedCountriesRepository] into the `account`
/// [DeniedCountriesPort].
class _GeofenceDeniedCountriesPort implements DeniedCountriesPort {
  _GeofenceDeniedCountriesPort(this._repo);

  final ReadDeniedCountriesRepository _repo;

  @override
  Future<bool> isDenied(String countryCode) => _repo.isDenied(countryCode);
}
