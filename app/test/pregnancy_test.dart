import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/family/profile_family_members.dart';
import 'package:app/balsm_app/flags.dart';
import 'package:app/balsm_app/kit.dart';
import 'package:app/balsm_app/pregnancy/api_pregnancy_guidance.dart';
import 'package:app/balsm_app/pregnancy/profile_pregnancy_babies.dart';
import 'package:app/balsm_app/screens/family/member_screen.dart';
import 'package:app/balsm_app/screens/home_screen.dart';
import 'package:app/balsm_app/screens/pregnancy/birth_screen.dart';
import 'package:app/balsm_app/screens/pregnancy/pregnancy_add_screen.dart';
import 'package:app/balsm_app/screens/pregnancy/pregnancy_home_card.dart';
import 'package:app/balsm_app/screens/pregnancy/pregnancy_kit.dart';
import 'package:app/balsm_app/screens/pregnancy/pregnancy_screen.dart';
import 'package:app/balsm_app/screens/pregnancy/pregnancy_start_screen.dart';
import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:family/family.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pregnancy/pregnancy.dart';
import 'package:profile/profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/flag_overrides.dart';

/// Mother & Child stage 4: the pregnancy tracker on the account holder's own
/// profile, its babies as prenatal profiles, and birth keeping the baby's
/// profile id. Every name and value here is invented by the test.
void main() {
  const user = UserId.value('u-pregnancy-test');
  late AppDatabase db;
  late GlobalKVDataSource kv;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    kv = await SharedPrefsKVDataSource.create();
  });
  tearDown(() => db.close());

  PatientAppState state() {
    final flags = flagsWith({AppFlags.motherChild: true});
    return PatientAppState()..attachFlags(flags);
  }

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<ProviderContainer> pump(WidgetTester tester, Widget screen, PatientAppState s, {bool settle = true}) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final container = ProviderContainer(
      retry: noProviderRetry,
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        currentUserIdProvider.overrideWithValue(user),
        globalKVDataSourceProvider.overrideWithValue(kv),
        familyMembersPortProvider.overrideWith(profileFamilyMembersPort),
        pregnancyBabiesPortProvider.overrideWith(profilePregnancyBabiesPort),
        // No guidance content (the fake answers 404): the card stays out.
        contentApiProvider.overrideWithValue(FakeContentApi()),
        pregnancyGuidanceSourceProvider.overrideWith(apiPregnancyGuidanceSource),
        accountSummaryProvider.overrideWith(
          (ref) async => const AccountSummary(
            id: user,
            displayName: 'Test Mother',
            countryCode: 'EG',
            preferredLanguage: 'en',
            deletionState: 'ACTIVE',
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: AppScope(
          state: s,
          child: MaterialApp(
            builder: (_, child) => Directionality(textDirection: s.dir, child: child!),
            home: Scaffold(body: screen),
          ),
        ),
      ),
    );
    settle ? await tester.pumpAndSettle() : await frames(tester);
    return container;
  }

  /// Starts a pregnancy with [babies] babies, 110 days before its due date.
  Future<Pregnancy> start(ProviderContainer c, {int babies = 1}) async {
    final self = await c.read(selfProfileIdProvider.future);
    final now = DateTime.now();
    final r = await c.read(startPregnancyUseCaseProvider)(
      motherId: self!,
      dueDate: now.add(const Duration(days: 110)),
      babyCount: babies,
      now: now,
      obName: 'Test Doctor',
    );
    return r.value;
  }

  group('ProfilePregnancyBabies (port → profile module)', () {
    test('babies are prenatal profiles: no sex, renamed, closed, and born with the same id', () async {
      final profiles = DriftProfileDataSource(db: db, activeUser: () => user);
      final port = ProfilePregnancyBabies(profiles: profiles, activeUser: () => user);
      await db.ensureSelfHealthProfile(user);
      const preg = PregnancyId.value('preg-test');
      final now = DateTime(2026, 11, 3);

      final a = (await port.addBaby(preg, sequence: 1, now: now)).value;
      final b = (await port.addBaby(preg, sequence: 2, now: now)).value;
      final stored = (await profiles.find(a.id))!;
      expect(stored.kind, ProfileKind.prenatal);
      expect(stored.sex, isNull);
      expect(stored.pregnancyId, preg);

      expect((await port.renameBaby(a.id, '  Test Bean ', now: now)).isSuccess, isTrue);
      expect((await port.listBabies(preg)).first.givenName, 'Test Bean');
      expect((await port.renameBaby(a.id, ' ', now: now)).isSuccess, isTrue);
      expect((await port.listBabies(preg)).first.givenName, isNull, reason: 'blank goes back to the label');

      expect((await port.closeBaby(b.id, now: now)).isSuccess, isTrue);
      expect((await port.listBabies(preg)).last.status, BabyStatus.closed);
      expect((await port.closeBaby(b.id, now: now)).error, isA<NotFoundFailure>());

      final born = await port.recordBirth(
        BirthDetails(
          babyId: a.id,
          name: 'Test Baby',
          sex: Sex.female,
          dateOfBirth: now,
          bloodType: BloodType.oPositive,
        ),
        now: now,
      );
      expect(born.isSuccess, isTrue);
      final child = (await profiles.find(a.id))!;
      expect(child.id, a.id, reason: 'birth keeps the prenatal profile id');
      expect(child.kind, ProfileKind.dependent);
      expect(child.relationship, Relationship.child);
      expect(child.sex, Sex.female);
      expect(child.bloodType, BloodType.oPositive);
      expect(MemberTone.tryFromWire(child.tone), isNotNull);
      expect((await port.listBabies(preg)).first.status, BabyStatus.born);
      expect(
        (await port.recordBirth(BirthDetails(babyId: b.id, name: 'x', sex: Sex.male, dateOfBirth: now), now: now))
            .error,
        isA<NotFoundFailure>(),
        reason: 'a baby no longer followed is not born',
      );
    });
  });

  group('dueLine', () {
    test('counts down, says due today, then counts the days past', () {
      final s = state();
      final p = s.strings.pregnancy;
      final due = DateTime(2026, 10);
      expect(dueLine(s, PregnancyInfo.on(due, DateTime(2026, 9, 29))), p.days_to_go(2));
      expect(dueLine(s, PregnancyInfo.on(due, DateTime(2026, 10))), p.due_today);
      expect(dueLine(s, PregnancyInfo.on(due, DateTime(2026, 10, 4))), p.days_past_due(3));
    });
  });

  group('Home', () {
    testWidgets('offers to start tracking; its ✕, once confirmed, hides it for this account, kept on the device',
        (tester) async {
      final s = state();
      final p = s.strings.pregnancy;
      final c = await pump(tester, const PregnancyHomeCards(), s);
      expect(find.text(p.prompt_b), findsOne);

      await tester.tap(find.bySemanticsLabel(p.hide_a11y));
      await tester.pumpAndSettle();
      expect(find.text(p.hide_title), findsOne);
      await tester.tap(find.text(s.strings.common.cancel));
      await tester.pumpAndSettle();
      expect(find.text(p.prompt_b), findsOne, reason: 'Cancel keeps the card');

      await tester.tap(find.bySemanticsLabel(p.hide_a11y));
      await tester.pumpAndSettle();
      await tester.tap(find.text(p.hide_btn));
      await tester.pumpAndSettle();

      expect(find.text(p.prompt_b), findsNothing);
      expect(await kv.get<bool>('pregnancy.prompt_dismissed.${user.value}'), isTrue);
      c.invalidate(pregnancyPromptDismissedProvider);
      await tester.pumpAndSettle();
      expect(find.text(p.prompt_b), findsNothing);
    });

    testWidgets('a tracked pregnancy shows its week on Home, not the prompt', (tester) async {
      final s = state();
      final p = s.strings.pregnancy;
      final c = await pump(tester, const HomeScreen(), s, settle: false);
      await start(c);
      await frames(tester);

      expect(find.text(p.week_n(24)), findsOne);
      expect(find.text(p.prompt_b), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    });
  });

  group('Start', () {
    testWidgets('the last-period mode estimates the due date; Start is off until a date is chosen', (tester) async {
      final s = state();
      final p = s.strings.pregnancy;
      await pump(tester, const PregnancyStartScreen(), s);
      final cta = find.widgetWithText(PButton, p.start_cta);
      expect(tester.widget<PButton>(cta).onTap, isNull);

      await tester.tap(find.text(p.mode_lmp));
      await tester.pumpAndSettle();
      await tester.tap(find.text(p.pick_date));
      await tester.pumpAndSettle();
      await tester.tap(find.text(s.strings.onboarding.dob_confirm));
      await tester.pumpAndSettle();

      expect(find.textContaining(p.est_due), findsOne);
      expect(tester.widget<PButton>(cta).onTap, isNotNull);
    });
  });

  group('Pregnancy screen', () {
    testWidgets('twins: week hero, Baby A and Baby B, no weekly guidance without content', (tester) async {
      final s = state();
      final p = s.strings.pregnancy;
      final c = await pump(tester, const SizedBox(), s);
      await start(c, babies: 2);
      await pump(tester, const PregnancyScreen(), s);

      expect(find.text('24'), findsOne);
      expect(find.text(p.babies), findsOne);
      expect(find.text(p.baby_lettered('A')), findsOne);
      expect(find.text(p.baby_lettered('B')), findsOne);
      expect(find.text(p.arrived_multi), findsOne);
      expect(find.textContaining('guidance'), findsNothing);
      expect(p.end_b.toLowerCase(), isNot(contains('remind')), reason: 'there is no reminder scheduler');
    });

    testWidgets('ending the pregnancy closes it and its babies; the records stay', (tester) async {
      final s = state();
      final p = s.strings.pregnancy;
      final c = await pump(tester, const SizedBox(), s);
      final preg = await start(c);
      await pump(tester, const PregnancyScreen(), s);

      await tester.tap(find.text(p.end_t));
      await tester.pumpAndSettle();
      expect(find.text(p.end_b), findsOne);
      await tester.tap(find.text(p.end_cta));
      await tester.pumpAndSettle();

      final self = await c.read(selfProfileIdProvider.future);
      final stored = await c.read(pregnanciesDataSourceProvider).find(preg.id, scope: self);
      expect(stored!.status, PregnancyStatus.ended);
      final babies = await c.read(pregnancyBabiesPortProvider).listBabies(preg.id);
      expect(babies.single.status, BabyStatus.closed);
    });
  });

  group('Attach', () {
    testWidgets('a measurement of the only baby is stored exactly as entered', (tester) async {
      final s = state();
      final p = s.strings.pregnancy;
      final c = await pump(tester, const SizedBox(), s);
      final preg = await start(c);
      final baby = (await c.read(pregnancyBabiesPortProvider).listBabies(preg.id)).single;
      await pump(tester, const PregnancyAddScreen(), s);

      await tester.tap(find.text(p.baby));
      await tester.pumpAndSettle();
      await tester.tap(find.text(p.kind_measure));
      await tester.pumpAndSettle();
      final save = find.widgetWithText(PButton, s.strings.family.save);
      expect(tester.widget<PButton>(save).onTap, isNull, reason: 'a measurement needs a value');
      await tester.enterText(find.widgetWithText(LabelledField, p.hr_field).last, '146');
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      final self = await c.read(selfProfileIdProvider.future);
      final items = await c.read(pregnanciesDataSourceProvider).findItems(preg.id, scope: self);
      expect(items.single.kind, ItemKind.measure);
      expect(items.single.fetalHeartRateBpm, 146);
      expect(items.single.babyIds, [baby.id]);
    });
  });

  group('Birth', () {
    testWidgets('one baby: name, sex and date → the same profile becomes the child; pregnancy closes as birth',
        (tester) async {
      final s = state();
      final f = s.strings.family;
      final p = s.strings.pregnancy;
      final c = await pump(tester, const SizedBox(), s);
      final preg = await start(c);
      final baby = (await c.read(pregnancyBabiesPortProvider).listBabies(preg.id)).single;
      final shown = await pump(tester, const BirthScreen(), s);

      final cta = find.widgetWithText(PButton, p.create_cta);
      expect(tester.widget<PButton>(cta).onTap, isNull, reason: 'no name or sex yet');
      await tester.enterText(find.byType(TextField).first, 'Test Newborn');
      await tester.tap(find.text(f.sex_male));
      await tester.pumpAndSettle();
      await tester.tap(cta);
      await tester.pumpAndSettle();

      final child = (await DriftProfileDataSource(db: db, activeUser: () => user).find(baby.id))!;
      expect(child.kind, ProfileKind.dependent);
      expect(child.displayName, 'Test Newborn');
      expect(child.sex, Sex.male);
      final self = await c.read(selfProfileIdProvider.future);
      expect((await c.read(pregnanciesDataSourceProvider).find(preg.id, scope: self))!.status, PregnancyStatus.birth);
      expect(shown.read(currentProfileIdProvider), baby.id, reason: 'the newborn becomes the active profile');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    });
  });

  group("A family member's pregnancy", () {
    Future<FamilyMember> member(
      ProviderContainer c, {
      Relationship rel = Relationship.child,
      Sex sex = Sex.female,
    }) async {
      await c.read(selfProfileIdProvider.future);
      final r = await c.read(saveFamilyMemberUseCaseProvider).add(
            MemberDraft(displayName: 'Test Daughter', relationship: rel, dateOfBirth: DateTime(1998, 4), sex: sex),
            userId: user,
            now: DateTime.now(),
          );
      return r.value;
    }

    Future<Pregnancy> startFor(ProviderContainer c, FamilyMember m) async {
      final now = DateTime.now();
      final r = await c.read(startPregnancyUseCaseProvider)(
        motherId: m.id,
        dueDate: now.add(const Duration(days: 110)),
        babyCount: 1,
        now: now,
      );
      return r.value;
    }

    testWidgets("her member screen offers pregnancy tracking; a man's does not", (tester) async {
      final s = state();
      final c = await pump(tester, const SizedBox(), s);
      final her = await member(c);
      final him = await member(c, sex: Sex.male);

      await pump(tester, MemberBody(member: her), s);
      expect(find.text(s.strings.family.tile_preg_off(s.gender)), findsOne);
      await pump(tester, MemberBody(member: him), s);
      expect(find.text(s.strings.family.tile_preg_off(s.gender)), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    });

    testWidgets("is stored on her profile and shown with her name, never as the account holder's", (tester) async {
      final s = state();
      final p = s.strings.pregnancy;
      final c = await pump(tester, const SizedBox(), s);
      final m = await member(c);
      final preg = await startFor(c, m);
      await pump(tester, PregnancyScreen(mother: m.id), s);

      expect(find.text(p.title_of('Test')), findsOne);
      expect(find.text(p.records_of('Test')), findsOne);
      expect(find.text(p.records_of_empty), findsOne);
      final self = await c.read(selfProfileIdProvider.future);
      final ds = c.read(pregnanciesDataSourceProvider);
      expect(await ds.findAll(scope: self), isEmpty);
      expect((await ds.findAll(scope: m.id)).single.id, preg.id);

      await pump(tester, MemberBody(member: m), s);
      expect(find.text(s.strings.family.tile_preg_off(s.gender)), findsNothing);
      expect(find.textContaining(p.week_n(24)), findsOne);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    });

    testWidgets("her baby joins the family as the account holder's relative, not their child", (tester) async {
      final s = state();
      final f = s.strings.family;
      final p = s.strings.pregnancy;
      final c = await pump(tester, const SizedBox(), s);
      final m = await member(c);
      final preg = await startFor(c, m);
      final baby = (await c.read(pregnancyBabiesPortProvider).listBabies(preg.id)).single;
      await pump(tester, BirthScreen(mother: m.id), s);

      await tester.enterText(find.byType(TextField).first, 'Test Grandchild');
      await tester.tap(find.text(f.sex_female));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PButton, p.create_cta));
      await tester.pumpAndSettle();

      final child = (await DriftProfileDataSource(db: db, activeUser: () => user).find(baby.id))!;
      expect(child.kind, ProfileKind.dependent);
      expect(child.relationship, Relationship.relative);
      expect((await c.read(pregnanciesDataSourceProvider).find(preg.id, scope: m.id))!.status, PregnancyStatus.birth);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    });
  });
}
