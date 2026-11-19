import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/family/profile_family_members.dart';
import 'package:app/balsm_app/flags.dart';
import 'package:app/balsm_app/kit.dart';
import 'package:app/balsm_app/screens/family/member_medical_screen.dart';
import 'package:app/balsm_app/screens/family/member_screen.dart';
import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:family/family.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:profile/profile.dart';

/// A family member's medical profile, trends and member-screen tiles
/// (mother-child.jsx `MCMedicalScreen`, `MCTrendsScreen`, `MCMemberBody`).
/// Every name and value here is invented by the test.
void main() {
  const user = UserId.value('u-member-health');
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  PatientAppState state() {
    final flags = FeatureFlags(flags: AppFlags.all, allowOverrides: true)..setOverride(AppFlags.motherChild, true);
    return PatientAppState()..attachFlags(flags);
  }

  Future<ProviderContainer> pump(WidgetTester tester, Widget screen, PatientAppState s) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      currentUserIdProvider.overrideWithValue(user),
      familyMembersPortProvider.overrideWith(profileFamilyMembersPort),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: AppScope(
        state: s,
        child: MaterialApp(
          builder: (_, child) => Directionality(textDirection: s.dir, child: child!),
          home: Scaffold(body: screen),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return container;
  }

  Future<FamilyMember> seed(
    ProviderContainer c, {
    String name = 'Test Member',
    Relationship rel = Relationship.child,
    Sex sex = Sex.female,
    DateTime? dob,
  }) async {
    await db.ensureSelfHealthProfile(user);
    final r = await c.read(saveFamilyMemberUseCaseProvider).add(
          MemberDraft(displayName: name, relationship: rel, dateOfBirth: dob ?? DateTime(2021, 3, 1), sex: sex),
          userId: user,
          now: DateTime.now(),
        );
    return r.value;
  }

  group('MemberMedicalScreen', () {
    testWidgets('edits blood type, allergies and conditions, and saves them to the member', (tester) async {
      final s = state();
      final c = await pump(tester, const SizedBox(), s);
      final m = await seed(c);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: AppScope(
          state: s,
          child: MaterialApp(home: Scaffold(body: MemberMedicalScreen(id: m.id))),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text(s.strings.family.medical_intro('Test')), findsOneWidget);
      expect(find.text(s.strings.family.medical_allergies_none), findsOneWidget);

      await tester.tap(find.text('B+'));
      await tester.enterText(find.byType(TextField).first, 'Test allergen');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.enterText(find.byType(TextField).last, 'Test condition');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Test allergen'), findsOneWidget);
      expect(find.text('Test condition'), findsOneWidget);

      await tester.tap(find.text(s.strings.family.save));
      await tester.pumpAndSettle();

      final stored = (await DriftProfileDataSource(db: db, activeUser: () => user).find(m.id))!;
      expect(stored.bloodType, BloodType.bPositive);
      expect(stored.allergies.map((a) => a.name), ['Test allergen']);
      expect(stored.conditions.map((x) => x.name), ['Test condition']);
      expect((await DriftProfileDataSource(db: db, activeUser: () => user).getProfile(user))!.allergies, isEmpty);
      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('Member screen tiles', () {
    testWidgets('shows the medical profile tile with the member\'s counts', (tester) async {
      final s = state();
      final c = await pump(tester, const SizedBox(), s);
      final m = await seed(c);
      await c.read(saveMedicalSummaryUseCaseProvider).execute(
          userId: user,
          profileId: m.id,
          bloodType: BloodType.oNegative,
          allergies: ['Test a', 'Test b'],
          conditions: ['Test c']);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: AppScope(state: s, child: MaterialApp(home: Scaffold(body: MemberBody(member: m)))),
      ));
      await tester.pumpAndSettle();

      final f = s.strings.family;
      expect(find.text(f.tile_medical), findsOneWidget);
      expect(find.text('O− · ${f.allergies_n(2)} · ${f.conditions_n(1)}'), findsOneWidget);
    });

    testWidgets('a wife reads as wife', (tester) async {
      final s = state();
      final c = await pump(tester, const SizedBox(), s);
      final m = await seed(c, rel: Relationship.spouse, dob: DateTime(1990, 1, 1));
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: AppScope(state: s, child: MaterialApp(home: Scaffold(body: MemberBody(member: m)))),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining(s.strings.family.rel_wife), findsOneWidget);
    });
  });
}
