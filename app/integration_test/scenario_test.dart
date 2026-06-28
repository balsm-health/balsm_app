// Route-driven screenshot scenario. Seeds an authenticated session + on-device
// PHI data, then walks the main screens capturing a screenshot of each.
// Run: flutter drive --driver=test_driver/integration_test.dart \
//   --target=integration_test/scenario_test.dart -d <sim> \
//   -t lib/main_dev.dart --dart-define-from-file=env/balsm/dev.json \
//   --dart-define-from-file=env/envs.json
import 'package:account/account.dart';
import 'package:auth/auth.dart';
import 'package:core/core.dart';
import 'package:emergency_card/emergency_card.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:medications/medications.dart';
import 'package:profile/profile.dart';

import 'package:app/app.dart';
import 'package:app/router.dart';

class _FakeEmergencyReader implements EmergencySnapshotReader {
  @override
  Future<EmergencyCardSnapshot?> readSnapshot() async => EmergencyCardSnapshot(
        bloodType: 'O+',
        allergyNames: const ['Penicillin'],
        conditionNames: const ['Hypertension'],
        primaryContact: (name: 'Sara Demo', phone: '+201000000000'),
        createdAt: DateTime.now(),
      );
}

Future<void> main() async {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('walk screens + screenshots', (tester) async {
    FlavorConfig.init(Flavor.dev);
    const uid = 'demo-user';
    final db = await AppDatabase.open();

    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      currentUserIdProvider.overrideWithValue(uid),
      balsmApiClientProvider.overrideWith(
        (ref) => BalsmApiClient.create(
          storage: const FlutterSecureStorage(),
          bus: ref.watch(eventBusProvider),
        ),
      ),
      secureStorageProvider.overrideWithValue(SecureStorageWrapper()),
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
      emergencySnapshotReaderProvider.overrideWith((ref) => _FakeEmergencyReader()),
    ]);
    addTearDown(container.dispose);

    // Seed on-device PHI so profile/medication screens show content.
    try {
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
    } catch (_) {/* seeding best-effort */}

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const BalsmApp()),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await binding.convertFlutterSurfaceToImage();

    final router = container.read(routerProvider);
    final steps = <(String, String)>[
      ('01_auth_country', '/auth/country'),
      ('02_auth_email', '/auth/email'),
      ('03_auth_otp', '/auth/otp?email=demo@balsm.health'),
      ('04_auth_social', '/auth/social'),
      ('05_home', '/home'),
      ('06_profile_editor', '/profile/editor'),
      ('07_handle_claim', '/account/handle'),
      ('08_settings', '/account/settings'),
      ('09_country_settings', '/account/country'),
      ('10_language_settings', '/account/language'),
      ('11_medications_list', '/medications'),
      ('12_medications_add', '/medications/add'),
      ('13_medications_today', '/medications/today'),
      ('14_emergency_card', '/emergency/card'),
      ('15_sessions', '/sessions'),
      ('16_deletion_request', '/deletion/request'),
    ];

    for (final (name, route) in steps) {
      try {
        router.go(route);
        await tester.pumpAndSettle(const Duration(milliseconds: 1200));
      } catch (_) {/* keep going; still screenshot whatever rendered */}
      await binding.takeScreenshot(name);
    }
  });
}
