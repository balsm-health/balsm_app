import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/screens/own_card_screen.dart';
import 'package:app/balsm_app/screens/profile_subscreens.dart';
import 'package:app/balsm_app/strings.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pregnancy/pregnancy.dart';
import 'package:profile/profile.dart';

const _self = HealthProfileId.value('hp-1');
final _at = DateTime(2025);

// Synthetic fixture: obviously fake values, no real person.
final _profile = HealthProfile(
  id: _self,
  userId: const UserId.value('u-1'),
  bloodType: BloodType.oPositive,
  allergies: [
    Allergy(
      id: const AllergyId.value('alg-1'),
      healthProfileId: _self,
      name: 'Test allergy',
      severity: 'mild',
      isControlledSubstance: false,
      createdAt: _at,
    ),
  ],
  conditions: const [],
  emergencyContacts: [
    EmergencyContact(
      id: const EmergencyContactId.value('ec-1'),
      healthProfileId: _self,
      name: 'Test Contact',
      phone: '+20 100 000 0000',
      relation: 'Friend',
      isPrimary: true,
      createdAt: _at,
    ),
  ],
  updatedAt: _at,
  displayName: 'Test Person',
);

void main() {
  testWidgets('shows the own card from the on-device profile, with no server call', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: noProviderRetry,
        overrides: [
          selfProfileIdProvider.overrideWith((ref) async => _self),
          healthProfileProvider.overrideWith((ref) async => _profile),
          accountSummaryProvider.overrideWith((ref) async => null),
          pregnanciesOfProvider.overrideWith((ref, _) => Stream.value(const <Pregnancy>[])),
        ],
        child: AppScope(
          state: PatientAppState(),
          child: const MaterialApp(home: OwnCardScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final f = stringsFor('en').family;
    expect(find.text(f.tile_card), findsWidgets);
    expect(find.text('Test Person'), findsOneWidget);
    expect(find.text('O+'), findsOneWidget);
    expect(find.text('Test allergy'), findsOneWidget);
    expect(find.textContaining('Test Contact', findRichText: true), findsOneWidget);
    expect(find.text(f.own_card_note), findsOneWidget);
  });
}
