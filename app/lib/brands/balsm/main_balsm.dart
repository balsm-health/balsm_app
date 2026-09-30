import 'dart:async';
import 'package:account/account.dart';
import 'package:auth/auth.dart';
import 'package:app_links/app_links.dart';
import 'package:core/core.dart';
import 'package:deletion/deletion.dart';
import 'package:emergency_card/emergency_card.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geofence_block/geofence_block.dart';
import 'package:profile/profile.dart';
import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/routes.dart';
import 'package:app/balsm_app/prefs.dart';
import 'package:app/balsm_app/screens/care_team_screen.dart';
import 'package:app/balsm_app/shell.dart';
import 'package:app/balsm_app/vault/bind_file_store.dart';
import 'package:app/balsm_app/care/map_packs/drift_map_pack_download_store.dart';
import 'package:app/balsm_app/care/map_packs/map_pack_download_controller.dart';
import 'package:app/balsm_app/care/map_packs/map_pack_download_store.dart';
import 'package:path_provider/path_provider.dart';

/// In-session holder for the signed-in user id. `currentUserIdProvider` reads
/// this, so an in-session sign-in / sign-out is reflected immediately (the
/// boot-time secure-storage value only seeds it). Updated by the
/// UserSignedIn / UserSignedOut bus listeners in [main].
final _sessionUserIdProvider = StateProvider<UserId?>((ref) => null);

/// Entrypoint for the claude.ai/design "Patient App" Flutter port.
/// Restores the persisted session so a signed-in user skips the auth flow.
/// Run: flutter run -t lib/brands/balsm/main_balsm.dart --flavor balsm \
///        --dart-define-from-file=env/balsm/dev.json \
///        --dart-define-from-file=env/shared.json
/// Boots the app. [extraOverrides] is appended AFTER the production overrides,
/// so an entry for the same provider wins — that is the seam the e2e build and
/// the Patrol tests use to swap the API layer for fakes.
///
/// [onContainerReady] runs once the container is built and the API layer is
/// initialised, immediately before `runApp`. Same idea as [extraOverrides]: a
/// seam for alternate entrypoints, used by the docshots build to seed the
/// on-device database. Production callers pass neither.
Future<void> bootstrap({
  List<Override> extraOverrides = const [],
  Future<void> Function(ProviderContainer container)? onContainerReady,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  FlavorConfig.initFromEnvironment();

  // Telemetry: crash reporting + user-action analytics via the AnalyticsLogger
  // facade (Sentry backend). See docs/superpowers/specs/2026-07-03-telemetry-*.
  await initSentry();

  // Dev Config log capture: hook debugPrint + framework/async errors into the
  // in-memory ring buffer surfaced by the Dev Config Logs tab. Installed AFTER
  // Sentry so our handler chains on top (Sentry still receives every error).
  // Gated to dev/staging — never hold app logs in prod memory.
  if (FlavorConfig.current.serverSwitchingEnabled) {
    DevLogBuffer.instance.install();
  }
  // Global KV store (shared_preferences behind the interface) — the only
  // place that constructs it; everything else sees KeyValueDataSource.
  final globalKV = await SharedPrefsKVDataSource.create();

  // Product analytics (PostHog): behaviour, funnels, campaign attribution.
  // Opt-OUT — on unless the patient turned it off in Profile → Privacy & data.
  // The choice is read from disk BEFORE the SDK is set up, so an opted-out
  // device emits nothing on this launch, not even the native
  // `$application_opened`. Crash reporting (Sentry, above) is deliberately NOT
  // gated by it — see kAnalyticsConsentDefault.
  final analyticsConsent = await AnalyticsConsent.load(globalKV);
  final postHogAnalytics = PostHogAnalyticsLogger(enabled: analyticsConsent.enabled);
  analyticsConsent.addSink(postHogAnalytics);
  // First-touch campaign attribution: the utm_* parameters on the link that
  // first opened the app, if any. Read here rather than in DeepLinkHandler
  // because it has to reach the SDK before the first event — and because
  // attribution is about the FIRST launch, which is a boot-time question.
  // The link's own token/fragment is never touched; only the marketing
  // parameters are read, and only the allowlisted ones.
  final campaign = await CampaignAttribution.resolve(
    globalKV,
    launchUri: await _launchUri(),
  );
  await initPostHog(analyticsEnabled: analyticsConsent.enabled, campaign: campaign);

  // On-device encrypted PHI database (opened once, injected as a value).
  final db = await AppDatabase.open();
  // Map-pack downloads live here — see map_pack_download_controller.dart.
  final mapPacksDir = await getApplicationSupportDirectory();
  // Current authenticated user id (opaque, non-PHI), if signed in. Read from
  // the platform secure store before the container is built.
  // The same store sign-in writes to — see SecureStorageWrapper.storage.
  const secureStorage = SecureStorageWrapper.storage;
  final userId = await secureStorage.read(key: 'balsm.user_id');

  // A session needs a REFRESH token to be revivable, not just an id. With the id
  // alone the shell opens signed-in and stays broken: every read resolves to
  // nothing, and the interceptor cannot mint a new access token, so on a
  // network the app cannot reach there is no rejection to fire SessionExpired
  // and nothing ever routes the patient out. Partial state like this comes from
  // a sign-out interrupted mid-way — the three keys are deleted one at a time.
  final refreshToken = await secureStorage.read(key: 'balsm.refresh_token');
  final revivable = userId != null && userId.isNotEmpty && refreshToken != null && refreshToken.isNotEmpty;
  if (userId != null && !revivable) {
    // Unrecoverable remnant. Clear it so the next launch agrees with the
    // keychain rather than repeating this.
    await secureStorage.delete(key: 'balsm.user_id');
    await secureStorage.delete(key: 'balsm.access_token');
  }
  final keychain = SecureStorageWrapper();
  UserId? containerUserId = revivable ? UserId.fromString(userId) : null;

  // App-shell state loads BEFORE the container so Riverpod can own it from
  // the first frame (patientAppStateProvider override below).
  final paPrefs = PatientAppPrefs(globalKV);
  await paPrefs.migrate();
  // Route on the credentials, not just the prefs flag — see load()'s doc.
  final state = await PatientAppState.load(paPrefs, hasSession: containerUserId != null);
  final fileStore = await createUserFileStore(
    activeUser: () => containerUserId,
    keychain: keychain,
  );

  final container = ProviderContainer(overrides: [
    // The app-shell state: one instance, owned by Riverpod (see app_state).
    patientAppStateProvider.overrideWith((ref) => state),
    // Fan out telemetry to a list of providers: Sentry (crash/diagnostics) and
    // PostHog (product analytics, consent-gated) always, plus a console sink
    // (scrubbed) added only in debug builds.
    analyticsLoggerProvider.overrideWithValue(
      MultiAnalyticsLogger([
        const SentryAnalyticsLogger(),
        postHogAnalytics,
        if (kDebugMode) const ConsoleAnalyticsLogger(),
      ]),
    ),
    // The patient's product-analytics choice, so Privacy & data can flip it.
    analyticsConsentProvider.overrideWith((ref) => analyticsConsent),
    // Bind the account module's adapter into core's cross-module read port so
    // other modules (e.g. home) read the account summary without importing it.
    readAccountRepositoryProvider.overrideWith(buildAccountAdapter),
    globalKVDataSourceProvider.overrideWithValue(globalKV),
    // ── Real P001 module provider seams (recovered from bootstrap.dart) ─────
    appDatabaseProvider.overrideWithValue(db),
    // Cached server read models (account summary, deny list, care directory).
    // Shares the encrypted database but its own table — see `_cacheSchema`.
    cacheStoreProvider.overrideWithValue(DriftCacheStore(db)),
    // Map-pack download state — its own two tables, see `_mapPacksSchema`.
    mapPackDownloadStoreProvider.overrideWithValue(DriftMapPackDownloadStore(db)),
    mapPackSupportDirProvider.overrideWithValue(mapPacksDir),
    // Reactive: reads the in-session holder (seeded from storage below), so
    // sign-in/out updates every PHI reader without an app restart.
    currentUserIdProvider.overrideWith((ref) => ref.watch(_sessionUserIdProvider)),
    // Flutter-side API controller owns the shared BalsmApiClient; the derived
    // balsmApiClientProvider reads `.client` off it.
    balsmApiControllerProvider.overrideWith(
      (ref) => BalsmApiController.create(
        storage: SecureStorageWrapper.storage,
        bus: ref.watch(eventBusProvider),
      ),
    ),
    secureStorageProvider.overrideWithValue(keychain),
    userFileStoreProvider.overrideWithValue(fileStore),
    // Emergency card reads the on-device HealthProfile (PHI stays on-device).
    emergencySnapshotReaderProvider.overrideWith(
      (ref) => _ProfileEmergencySnapshotReader(ref),
    ),
    // Profile QR identity payload (spec v2.0): name/DOB/gender from the
    // account profile, language from app prefs. Offline → null identity
    // fields; the standing refresh path fills them in later.
    profileIdentityReaderProvider.overrideWith(
      (ref) => _AccountProfileIdentityReader(ref, PatientAppPrefs(globalKV)),
    ),
    // Account country-change consults the geofence denied-countries repo.
    reauthPortProvider.overrideWith((ref) => _AuthReauthPort(ref)),
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
    // ── Care-team cloud sync (structured PHI rows → Balsm's own database) ──
    // Distinct from the Drive blob backup above, and running alongside it: this
    // mirrors care_provider rows to Balsm so the roster survives device loss for
    // patients with no Google session (email-OTP / Apple), who get no blob at all.
    careTeamSyncServiceProvider.overrideWith((ref) => CareTeamSyncService(
          api: ref.watch(careTeamApiProvider),
          outbox: SyncOutboxDao(ref.watch(appDatabaseProvider)),
          db: ref.watch(appDatabaseProvider),
          // Its OWN status, not the Drive backup's — see careTeamSyncStatusProvider.
          status: ref.watch(careTeamSyncStatusProvider.notifier),
          activeUser: () => ref.read(currentUserIdProvider),
          // customStatement does not notify drift streams, so merged rows stay
          // invisible without this.
          onChanged: () => ref.invalidate(careTeamProvider),
        )),
    restoreServiceProvider.overrideWith((ref) => RestoreService(
          adapter: DriveBackupAdapter(),
          snapshot: ref.watch(snapshotServiceProvider),
          storage: ref.watch(secureStorageProvider),
          userId: ref.watch(currentUserIdProvider)?.value ?? 'local',
        )),
    ...extraOverrides,
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
  container.read(_sessionUserIdProvider.notifier).state = UserId.fromString(userId);
  // Bind telemetry to the restored session (opaque id only). Null when signed
  // out, which resets the analytics identity — see the sign-out listener.
  analytics.setUser(containerUserId?.value);

  // Keep the in-session user id live: sign-in sets it, sign-out clears it, so
  // every PHI reader (profile/meds/emergency/backup) sees the current user
  // without an app restart.
  container.read(eventBusProvider).on<UserSignedIn>().listen((e) {
    // A different account taking over mid-process (crash skipped the
    // sign-out sweep): the stored permanent QR belongs to the PREVIOUS
    // account — its jti resolves to their identity payload. Drop it before
    // the new session can display or refresh it.
    if (containerUserId != null && containerUserId != e.userId) {
      unawaited(container.read(permanentQrStoreProvider).clear());
    }
    containerUserId = e.userId;
    container.read(_sessionUserIdProvider.notifier).state = e.userId;
    // Opaque id only. Attributes this session's telemetry to the account that
    // is actually signed in — without it every event stays on the device's
    // anonymous id and cohort/retention reporting is meaningless.
    analytics.setUser(e.userId.value);
    // Also on sign-IN, not just sign-out: a crash mid-session leaves rows
    // behind, and the next account to sign in would inherit them. Re-fetching
    // a summary on sign-in is correct anyway.
    unawaited(container.read(cacheStoreProvider).clearAll());
  });
  container.read(eventBusProvider).on<UserSignedOut>().listen((_) {
    containerUserId = null;
    container.read(_sessionUserIdProvider.notifier).state = null;
    // Severs the analytics identity. Without this the next account to sign in
    // on this device keeps emitting under the previous patient's person — the
    // telemetry equivalent of the cache and permanent-QR sweeps below, and the
    // reason this is a privacy fix rather than a metrics one.
    analytics.setUser(null);
    // Cached read models are per-account. Leaving them would show the previous
    // user's handle to whoever signs in next on this device.
    unawaited(container.read(cacheStoreProvider).clearAll());
    // The permanent profile QR is account-owned (jti + AES key). Left in the
    // keychain it would render the previous user's QR — and decrypt their
    // identity payload — for whoever signs in next on this device.
    unawaited(container.read(permanentQrStoreProvider).clear());
  });

  // T173: country change → refresh locale-derived state. Re-fetches the
  // account summary so greeting/locale-dependent reads reflect the change.
  // App-lifetime subscription, mirrors the forwarder above.
  container.read(eventBusProvider).on<CountryChanged>().listen((_) async {
    await container.read(readAccountRepositoryProvider).refresh('self');
    container.invalidate(accountSummaryProvider);
  });

  // Apply the persisted server preset BEFORE the first API call: init() reads
  // the saved preset (`saved ?? defaultServer`) and sets the client base URL.
  // Without this the dev server-selector choice (Local / Staging) is dropped on
  // every relaunch and the app silently reverts to the default server. Must run
  // before runApp — no API request is issued before this point.
  await container.read(balsmApiControllerProvider).init();

  // Permanent medical-profile QR: if one exists, silently re-sync its
  // server-side ciphertext with the current on-device profile so a scan
  // always shows current data. No-op when nothing changed or no permanent
  // QR exists; failures retry on the next launch / sheet open.
  if (containerUserId != null) {
    unawaited(container.read(refreshPermanentQrUseCaseProvider)());
  }

  // Migrate the app-shell preference group before its first read.
  // A dead API session (the refresh was REJECTED — the transport has already
  // cleared the stored tokens). Mirror it in-app: drop the in-session user id
  // so every PHI reader goes null, persist signed-out, and leave the shell NOW.
  //
  // The route change is the part that was missing. Without it the patient sat
  // in the signed-in shell with no session: every read resolved to nothing, and
  // because the tokens were already gone there was no second failure to fire
  // another event. The only escape was relaunching the app — and Profile, where
  // the sign-out button lives, was one of the screens showing nothing.
  //
  // Declared after load() because it needs the state object it routes on.
  container.read(eventBusProvider).on<SessionExpired>().listen((_) {
    containerUserId = null;
    container.read(_sessionUserIdProvider.notifier).state = null;
    // Same reason as the UserSignedOut sweep: the session is over, so the
    // analytics identity must not carry into whoever signs in next.
    analytics.setUser(null);
    paPrefs.setSignedIn(false);
    unawaited(container.read(cacheStoreProvider).clearAll());
    if (state.route == AppRoutes.app) state.go(AppRoutes.welcome);
  });
  if (onContainerReady != null) await onContainerReady(container);
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: PatientApp(navObserver: AnalyticsRouteObserver(analytics)),
    ),
  );
}

/// Adapts the `profile` package's on-device DAO into the `emergency_card`
/// [EmergencySnapshotReader] port. PHI never leaves the device here.
class _AccountProfileIdentityReader implements ProfileIdentityReader {
  _AccountProfileIdentityReader(this._ref, this._prefs);

  final Ref _ref;
  final PatientAppPrefs _prefs;

  @override
  Future<ProfileQrPayload> readIdentity() async {
    String? name;
    String? dob;
    String? gender;
    try {
      final details = await _ref.read(accountProfileUseCaseProvider).load();
      if (details != null) {
        final joined =
            [details.firstName, details.lastName].whereType<String>().where((part) => part.isNotEmpty).join(' ');
        name = details.displayName ?? (joined.isEmpty ? null : joined);
        dob = details.dateOfBirth;
        gender = details.gender?.name;
      }
    } catch (_) {
      // Offline or signed out mid-flow — mint an identity-less payload; the
      // refresh use case rewrites it once the profile is reachable.
    }
    final lang = await _prefs.lang();
    return ProfileQrPayload(
      name: name,
      dateOfBirth: dob,
      gender: gender,
      lang: lang,
      createdAt: DateTime.now(),
    );
  }
}

class _ProfileEmergencySnapshotReader implements EmergencySnapshotReader {
  _ProfileEmergencySnapshotReader(this._ref);

  final Ref _ref;

  @override
  Future<EmergencyCardSnapshot?> readSnapshot() async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return null;
    final profile = await _ref.read(profileDataSourceProvider).getProfile(userId);
    if (profile == null) return null;

    final primary = profile.emergencyContacts
        .where((c) => c.isPrimary)
        .cast<EmergencyContact?>()
        .firstWhere((_) => true, orElse: () => null);

    return EmergencyCardSnapshot(
      bloodType: profile.bloodType,
      allergyNames: profile.allergies.map((a) => a.name).toList(),
      conditionNames: profile.conditions.map((c) => c.name).toList(),
      primaryContact: primary == null ? null : (name: primary.name, phone: primary.phone),
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

/// The link that launched this run, or null for a normal launch.
///
/// Guarded and time-boxed: this is a platform-channel call on the boot path, and
/// campaign attribution is never worth delaying — let alone failing — a launch
/// over. `DeepLinkHandler` reads the same link again for routing; querying it
/// twice is free.
Future<Uri?> _launchUri() async {
  try {
    return await AppLinks().getInitialLink().timeout(const Duration(seconds: 2));
  } catch (_) {
    return null;
  }
}

/// Production entrypoint. See [bootstrap].
Future<void> main() => bootstrap();

/// Binds `deletion`'s [ReauthPort] to `auth`'s OTP use cases.
///
/// `deletion` must not import `auth`, so the composition happens here. This
/// reuses the same challenge the app's own sign-in uses: proving control of
/// the mailbox is exactly the bar for deleting what that mailbox owns.
class _AuthReauthPort implements ReauthPort {
  _AuthReauthPort(this._ref);

  final Ref _ref;

  @override
  Future<AppResult<void>> requestChallenge(ReauthChannel channel, String identifier) async {
    if (channel != ReauthChannel.email) {
      return AppResult.failure(const ValidationFailure('Use your account email.'));
    }
    final country = _ref.read(patientAppStateProvider).country.value;
    return _ref.read(signInUseCaseProvider).requestEmailOtp(identifier, country);
  }

  @override
  Future<AppResult<void>> verify(ReauthCredentials credentials) async {
    if (credentials.channel != ReauthChannel.email) {
      return AppResult.failure(const ValidationFailure('Use your account email.'));
    }
    final result = await _ref.read(signInUseCaseProvider).verifyEmailOtp(
          email: credentials.identifier,
          code: credentials.secret,
        );
    return switch (result) {
      AppSuccess() => AppResult.success(null),
      AppFailureResult(:final failure) => AppResult.failure(failure),
    };
  }
}
