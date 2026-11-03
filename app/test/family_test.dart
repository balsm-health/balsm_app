import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/family/family_flag_guard.dart';
import 'package:app/balsm_app/family/profile_family_members.dart';
import 'package:app/balsm_app/flags.dart';
import 'package:app/balsm_app/kit.dart';
import 'package:app/balsm_app/screens/family/family_screen.dart';
import 'package:app/balsm_app/screens/family/profile_bar.dart';
import 'package:app/balsm_app/screens/home_screen.dart';
import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:family/family.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:profile/profile.dart';

/// Mother & Child stage 2: family members on this phone, the people picker
/// that re-points the active profile, and today's app with the flag off.
/// Every name here is invented by the test.
void main() {
  const user = UserId.value('u-family-test');
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  PatientAppState familyState({bool on = true}) {
    final flags = FeatureFlags(flags: AppFlags.all, allowOverrides: true)..setOverride(AppFlags.motherChild, on);
    return PatientAppState()..attachFlags(flags);
  }

  /// Home keeps loading animations and drift streams alive, so it is pumped a
  /// few frames rather than settled, and unmounted before the test ends.
  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<ProviderContainer> pump(WidgetTester tester, Widget screen, PatientAppState state,
      {bool settle = true}) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      currentUserIdProvider.overrideWithValue(user),
      familyMembersPortProvider.overrideWith(profileFamilyMembersPort),
      accountSummaryProvider.overrideWith((ref) async => const AccountSummary(
            id: user,
            displayName: 'Test Parent',
            countryCode: 'EG',
            preferredLanguage: 'en',
            deletionState: 'ACTIVE',
          )),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: AppScope(
        state: state,
        child: MaterialApp(
          builder: (_, child) => Directionality(textDirection: state.dir, child: child!),
          home: Scaffold(body: screen),
        ),
      ),
    ));
    settle ? await tester.pumpAndSettle() : await frames(tester);
    return container;
  }

  Future<FamilyMember> seed(ProviderContainer c, String name, {Relationship rel = Relationship.child}) async {
    final r = await c.read(saveFamilyMemberUseCaseProvider).add(
          MemberDraft(displayName: name, relationship: rel, dateOfBirth: DateTime(2021, 3, 1), sex: Sex.female),
          userId: user,
          now: DateTime.now(),
        );
    return r.value;
  }

  group('ProfileFamilyMembers (port → profile module)', () {
    test('creates, edits and closes dependents beside the self profile, live', () async {
      final profiles = DriftProfileDataSource(db: db, activeUser: () => user);
      final port = ProfileFamilyMembers(profiles: profiles, activeUser: () => user);
      final selfId = await db.ensureSelfHealthProfile(user);
      final seen = <List<String>>[];
      final sub = port.watchMembers().listen((m) => seen.add([for (final x in m) x.displayName]));
      await pumpEventQueue();

      final created = await port.createMember(
        MemberDraft(
          displayName: 'Test Child',
          relationship: Relationship.child,
          dateOfBirth: DateTime(2022, 6, 1),
          sex: Sex.male,
          bloodType: BloodType.oPositive,
        ),
        groupId: null,
        tone: MemberTone.violet,
        now: DateTime(2026, 11, 3),
      );
      await pumpEventQueue();
      final id = created.value.id;
      final stored = (await profiles.find(id))!;
      expect(stored.kind, ProfileKind.dependent);
      expect(stored.bloodType, BloodType.oPositive);
      expect(stored.tone, 'violet');
      expect((await profiles.getProfile(user))!.id, selfId, reason: 'self stays self');

      final edited = await port.updateMember(
        id,
        MemberDraft(displayName: 'Test Renamed', relationship: Relationship.child, dateOfBirth: null, sex: Sex.male),
        groupId: null,
        now: DateTime(2026, 11, 3),
      );
      await pumpEventQueue();
      expect(edited.value.displayName, 'Test Renamed');
      expect((await profiles.find(id))!.bloodType, isNull, reason: '"Not sure" clears the blood type');

      expect((await port.closeMember(id, now: DateTime(2026, 11, 3))).isSuccess, isTrue);
      await pumpEventQueue();
      expect((await port.closeMember(id, now: DateTime(2026, 11, 3))).error, isA<NotFoundFailure>());
      expect(
          (await port.updateMember(
                  selfId, const MemberDraft(displayName: 'x', relationship: null, dateOfBirth: null, sex: null),
                  groupId: null, now: DateTime(2026, 11, 3)))
              .error,
          isA<NotFoundFailure>(),
          reason: 'self is never edited as a member');
      await sub.cancel();

      // A details edit writes twice (details, then blood type), so the same
      // list can arrive twice in a row; what matters is the sequence.
      final changes = [
        for (final (i, x) in seen.indexed)
          if (i == 0 || x.join() != seen[i - 1].join()) x
      ];
      expect(changes, [
        <String>[],
        ['Test Child'],
        ['Test Renamed'],
        <String>[],
      ]);
    });

    test('a rule the profile aggregate breaks comes back as a validation failure', () async {
      final port = ProfileFamilyMembers(
          profiles: DriftProfileDataSource(db: db, activeUser: () => user), activeUser: () => user);
      final r = await port.createMember(
        MemberDraft(displayName: 'Test', relationship: Relationship.child, dateOfBirth: DateTime(2099), sex: Sex.male),
        groupId: null,
        tone: MemberTone.aqua,
        now: DateTime(2026, 11, 3),
      );
      expect(r.error, isA<ValidationFailure>());
      expect(r.error.message, contains('birthDateInFuture'));
    });
  });

  group('Family screen', () {
    testWidgets('shows the empty state, then members grouped under their group', (tester) async {
      final state = familyState();
      final c = await pump(tester, const FamilyScreen(), state);
      final f = state.strings.family;
      expect(find.text(f.empty_t), findsOne);
      expect(find.text(f.stays_local), findsOne);

      await seed(c, 'Test Daughter');
      await tester.pumpAndSettle();

      expect(find.text(f.empty_t), findsNothing);
      expect(find.text(f.group_family), findsOne);
      expect(find.text('Test Daughter'), findsOne);
    });

    testWidgets('the add sheet offers manual entry only — no QR scan', (tester) async {
      final state = familyState();
      await pump(tester, const FamilyScreen(), state);
      await tester.tap(find.text(state.strings.family.add_member));
      await tester.pumpAndSettle();

      expect(find.text(state.strings.family.manual_t), findsOne);
      expect(find.text(state.strings.common.fam_scan_qr(Gender.other)), findsNothing);
    });

    testWidgets('adding a child stores them, files them in My family and makes them active', (tester) async {
      final state = familyState();
      final f = state.strings.family;
      final c = await pump(tester, const FamilyScreen(), state);
      await tester.tap(find.text(f.add_member));
      await tester.pumpAndSettle();
      await tester.tap(find.text(f.manual_t));
      await tester.pumpAndSettle();

      final save = find.widgetWithText(PButton, f.save);
      expect(tester.widget<PButton>(save).onTap, isNull, reason: 'nothing filled in yet');

      await tester.tap(find.text(f.pick_son));
      await tester.enterText(find.byType(TextField).first, 'Test Son');
      await tester.tap(find.text(f.f_dob_ph));
      await tester.pumpAndSettle();
      await tester.tap(find.text(state.strings.onboarding.dob_confirm));
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      final members = await c.read(familyMembersPortProvider).listMembers();
      expect(members.single.displayName, 'Test Son');
      expect(members.single.relationship, Relationship.child);
      expect(members.single.sex, Sex.male, reason: 'the Son chip sets the sex');
      expect(await db.resolveActiveHealthProfile(user), members.single.id);
      expect(find.text('Test Son'), findsOne);
      expect(find.text(f.group_family), findsOne);
    });
  });

  group('People picker', () {
    testWidgets('choosing a member re-points the active profile; choosing yourself goes back', (tester) async {
      final state = familyState();
      final f = state.strings.family;
      final c = await pump(tester, const ProfileBar(family: true), state);
      final selfId = await db.ensureSelfHealthProfile(user);
      final child = await seed(c, 'Test Kid');
      await tester.pumpAndSettle();
      expect(find.textContaining(f.bar_your_profile, findRichText: true), findsOne);

      await tester.tap(find.byType(ProfileBar));
      await tester.pumpAndSettle();
      expect(find.text(f.picker_title(Gender.other)), findsOne);
      await tester.tap(find.text('Test Kid'));
      await tester.pumpAndSettle();

      expect(c.read(currentProfileIdProvider), child.id);
      expect(find.textContaining('Test · ${f.rel_daughter}', findRichText: true), findsOne);

      await tester.tap(find.byType(ProfileBar));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test Parent'));
      await tester.pumpAndSettle();
      expect(c.read(currentProfileIdProvider), selfId);
    });
  });

  group('Home', () {
    testWidgets('flag on: profile bar under the header, the member home while a member is active', (tester) async {
      final state = familyState();
      final f = state.strings.family;
      final c = await pump(tester, const HomeScreen(), state, settle: false);
      expect(find.byType(ProfileBar), findsOne);
      expect(find.text(f.tile_card), findsNothing);

      final child = await seed(c, 'Test Kid');
      await c.read(activeProfileSwitcherProvider).select(child.id);
      await frames(tester);

      expect(find.text('Test Kid'), findsOne);
      expect(find.text(f.tile_card), findsOne);
      expect(find.text(f.tile_meds), findsOne);
      expect(find.text(f.tile_records), findsOne);
      await unmount(tester);
    });

    testWidgets('flag off: today\'s home — no profile bar, the session-only banner still works', (tester) async {
      final state = familyState(on: false)..addFamilyMember(name: 'Test Relative', relation: 'Father');
      state.selectFamilyMember(state.extraFamily.first.id);
      await pump(tester, const HomeScreen(), state, settle: false);

      expect(find.byType(ProfileBar), findsNothing);
      expect(find.text(state.strings.home.viewing_member('Test Relative')), findsOne);
      await unmount(tester);
    });
  });

  group('keepSelfActiveWithoutFamily', () {
    const self = HealthProfileId.value('hp-self');
    const kid = HealthProfileId.value('hp-kid');

    Future<(bool, int)> run({required bool on, HealthProfileId? active}) async {
      var calls = 0;
      final switched = await keepSelfActiveWithoutFamily(
        familyOn: on,
        active: active,
        self: () async => self,
        selectSelf: () async => calls++,
      );
      return (switched, calls);
    }

    test('flag off with a member active: back to self', () async {
      expect(await run(on: false, active: kid), (true, 1));
    });

    test('flag off on self, flag on, or nothing resolved yet: no change', () async {
      expect(await run(on: false, active: self), (false, 0));
      expect(await run(on: true, active: kid), (false, 0));
      expect(await run(on: false), (false, 0));
    });
  });
}
