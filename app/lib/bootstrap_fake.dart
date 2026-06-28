import 'package:account/account.dart';
import 'package:auth/auth.dart';
import 'package:core/core.dart';
import 'package:emergency_card/emergency_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geofence_block/geofence_block.dart';
import 'package:medications/medications.dart';
import 'package:profile/profile.dart';

/// DEV-only bootstrap that boots the app pre-authenticated with seeded demo
/// data, so screens render "fake success" content without a live backend.
///
/// Mirrors `integration_test/scenario_test.dart`, but for an interactive run:
/// ```
/// flutter run -t lib/main_fake.dart --flavor dev \
///   --dart-define-from-file=env/balsm/dev.json \
///   --dart-define-from-file=env/envs.json
/// ```
Future<List<Override>> bootstrapFake() async {
  const uid = 'demo-user';
  final db = await AppDatabase.open();

  // Seed on-device PHI so profile / medication / emergency screens show data.
  // Best-effort: a re-run hits existing rows, which is fine.
  try {
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      currentUserIdProvider.overrideWithValue(uid),
    ]);
    final profileDao = container.read(profileDaoProvider);
    final profileId = UuidV7.generate();
    await profileDao.upsertProfile(HealthProfile(
      id: profileId,
      userId: uid,
      bloodType: 'O+',
      allergies: const [],
      conditions: const [],
      emergencyContacts: const [],
      updatedAt: DateTime.now(),
    ));
    await profileDao.addAllergy(
      profileId,
      Allergy(
        id: UuidV7.generate(),
        healthProfileId: profileId,
        name: 'Penicillin',
        severity: 'severe',
        isControlledSubstance: false,
        createdAt: DateTime.now(),
      ),
    );
    await container.read(medicationDaoProvider).addMedication(Medication(
          id: UuidV7.generate(),
          userId: uid,
          name: 'Metformin',
          doseAmount: '500mg',
          scheduleType: ScheduleType.daily,
          scheduleConfig: const ScheduleConfig(times: ['08:00', '20:00']),
          startDate: DateTime.now().subtract(const Duration(days: 2)),
        ));
    container.dispose();
  } catch (_) {/* seeding best-effort */}

  return <Override>[
    appDatabaseProvider.overrideWithValue(db),
    currentUserIdProvider.overrideWithValue(uid),
    secureStorageProvider.overrideWithValue(FakeSecureStorage()),
    balsmApiClientProvider.overrideWith((ref) => FakeBalsmApiClient()),

    // Pretend we're signed in — skips the auth flow, lands on /home.
    authSessionProvider.overrideWith(
      (ref) => Stream.value(const Authenticated(
        userId: uid,
        email: 'demo@balsm.health',
        provider: 'email',
        accessToken: 'x',
        refreshToken: 'y',
      )),
    ),
    accountSummaryProvider.overrideWith((ref) async => const AccountSummary(
          id: uid,
          handle: 'demo',
          displayName: 'Demo Patient',
          countryCode: 'EG',
          preferredLanguage: 'en',
          deletionState: 'ACTIVE',
        )),

    // Emergency card reads on-device HealthProfile (same wiring as prod).
    emergencySnapshotReaderProvider.overrideWith(
      (ref) => _ProfileEmergencySnapshotReader(ref),
    ),
    deniedCountriesPortProvider.overrideWith(
      (ref) => _GeofenceDeniedCountriesPort(
        ref.watch(deniedCountriesRepositoryProvider),
      ),
    ),
  ];
}

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

class _GeofenceDeniedCountriesPort implements DeniedCountriesPort {
  _GeofenceDeniedCountriesPort(this._repo);

  final ReadDeniedCountriesRepository _repo;

  @override
  Future<bool> isDenied(String countryCode) => _repo.isDenied(countryCode);
}
