import 'package:account/account.dart';
import 'package:core/core.dart';
import 'package:emergency_card/emergency_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geofence_block/geofence_block.dart';
import 'package:profile/profile.dart';

/// Builds the Riverpod provider overrides for the app's [ProviderScope].
///
/// Called from each `main_<flavor>.dart` before `runApp`:
/// ```dart
/// final overrides = await bootstrap();
/// runApp(ProviderScope(overrides: overrides, child: const BalsmApp()));
/// ```
Future<List<Override>> bootstrap() async {
  const storage = FlutterSecureStorage();

  // On-device encrypted PHI database.
  final db = await AppDatabase.open();

  // Current authenticated user id (opaque, non-PHI), if signed in.
  final userId = await storage.read(key: 'balsm.user_id');

  return <Override>[
    appDatabaseProvider.overrideWithValue(db),
    currentUserIdProvider.overrideWithValue(userId),
    balsmApiClientProvider.overrideWith(
      (ref) => BalsmApiClient.create(
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
        userId: ref.watch(currentUserIdProvider) ?? 'local',
        onlineStream: connectivityOnlineStream(),
      );
      ref.onDispose(service.dispose);
      return service;
    }),
    restoreServiceProvider.overrideWith((ref) => RestoreService(
          adapter: DriveBackupAdapter(),
          snapshot: ref.watch(snapshotServiceProvider),
          storage: ref.watch(secureStorageProvider),
          userId: ref.watch(currentUserIdProvider) ?? 'local',
        )),
  ];
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
