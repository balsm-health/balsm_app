import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/family/profile_family_members.dart';
import 'package:app/balsm_app/flags.dart';
import 'package:app/balsm_app/kit.dart';
import 'package:app/balsm_app/screens/family/family_kit.dart';
import 'package:app/balsm_app/screens/family/growth_screen.dart';
import 'package:app/balsm_app/screens/family/health_log_form.dart';
import 'package:app/balsm_app/screens/family/member_screen.dart';
import 'package:app/balsm_app/screens/family/vaccinations_screen.dart';
import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:family/family.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vaccinations/vaccinations.dart';

/// Mother & Child stage 3: a child's vaccinations and growth log, and their
/// tiles on the member home. Every name and value here is invented by the
/// test.
void main() {
  const user = UserId.value('u-vacc-test');
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  final today = DateTime.now();
  DateTime daysFromToday(int n) => DateTime(today.year, today.month, today.day + n);

  PatientAppState familyState() {
    final flags = FeatureFlags(flags: AppFlags.all, allowOverrides: true)..setOverride(AppFlags.motherChild, true);
    return PatientAppState()..attachFlags(flags);
  }

  Future<ProviderContainer> pump(WidgetTester tester, Widget screen, PatientAppState state) async {
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
    await tester.pumpAndSettle();
    return container;
  }

  Future<FamilyMember> seed(ProviderContainer c, String name, DateTime dob) async {
    final r = await c.read(saveFamilyMemberUseCaseProvider).add(
          MemberDraft(displayName: name, relationship: Relationship.child, dateOfBirth: dob, sex: Sex.female),
          userId: user,
          now: DateTime.now(),
        );
    return r.value;
  }

  /// A container just for seeding, before a screen that needs the member id.
  Future<FamilyMember> seedFirst(String name, {DateTime? dob}) async {
    final c = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      currentUserIdProvider.overrideWithValue(user),
      familyMembersPortProvider.overrideWith(profileFamilyMembersPort),
    ]);
    addTearDown(c.dispose);
    return seed(c, name, dob ?? DateTime(today.year - 4, 3, 1));
  }

  Future<void> dose(ProviderContainer c, HealthProfileId id, String vaccine, int n,
      {required DateTime given, DateTime? next}) async {
    final r = await c.read(recordVaccinationUseCaseProvider)(
      vaccine: vaccine,
      doseNumber: n,
      administeredOn: given,
      nextDueOn: next,
      now: DateTime.now(),
      profileId: id,
    );
    expect(r.isSuccess, isTrue);
  }

  group('Member home tiles', () {
    testWidgets('a child gets Vaccinations and Growth; they follow the logs', (tester) async {
      final state = familyState();
      final kid = await seedFirst('Test Kid');
      final c = await pump(tester, MemberScreen(id: kid.id), state);
      expect(find.text(state.strings.vacc.title), findsOne);
      expect(find.text(state.strings.vacc.recorded_n(0)), findsOne);
      expect(find.text(state.strings.growth.tile_empty), findsOne);

      await dose(c, kid.id, 'Test Vaccine', 1, given: daysFromToday(-20));
      await tester.pumpAndSettle();
      expect(find.text(state.strings.vacc.recorded_n(1)), findsOne);

      final next = daysFromToday(12);
      await dose(c, kid.id, 'Test Vaccine', 2, given: daysFromToday(-2), next: next);
      await c.read(recordGrowthEntryUseCaseProvider)(
          measuredOn: daysFromToday(-3), weightKg: 14, heightCm: null, now: DateTime.now(), profileId: kid.id);
      await tester.pumpAndSettle();
      expect(find.text(state.strings.vacc.tile_next(formatDay(next))), findsOne);
      expect(find.text(state.strings.growth.tile_last(formatDay(daysFromToday(-3)))), findsOne);
    });

    testWidgets('an adult member gets neither tile', (tester) async {
      final state = familyState();
      final adult = await seedFirst('Test Adult', dob: DateTime(today.year - 40, 1, 1));
      await pump(tester, MemberScreen(id: adult.id), state);
      expect(find.text(state.strings.family.tile_card), findsOne);
      expect(find.text(state.strings.vacc.title), findsNothing);
      expect(find.text(state.strings.growth.title), findsNothing);
    });
  });

  group('Vaccinations', () {
    testWidgets('empty state, then next dose, past due and given doses', (tester) async {
      final state = familyState();
      final v = state.strings.vacc;
      final kid = await seedFirst('Test Kid');
      final c = await pump(tester, VaccinationsScreen(id: kid.id), state);
      expect(find.text(v.empty_t), findsOne);

      await dose(c, kid.id, 'Test Alpha', 1, given: daysFromToday(-60), next: daysFromToday(10));
      await dose(c, kid.id, 'Test Beta', 1, given: daysFromToday(-90), next: daysFromToday(-5));
      await tester.pumpAndSettle();

      expect(find.text(v.empty_t), findsNothing);
      expect(find.text(v.next_dose), findsOne);
      expect(find.text('Test Alpha · ${v.dose(2)}'), findsOne);
      expect(find.text(v.past_due), findsOne);
      expect(find.text('Test Beta · ${v.dose(2)}'), findsOne);
      expect(find.text('${v.was_due(formatDay(daysFromToday(-5)))} · ${v.days_ago(5)}'), findsOne);
      expect(find.text(v.given), findsOne);
      expect(find.text('Test Alpha'), findsOne);
      expect(find.text('Test Beta'), findsOne);

      await tester.tap(find.text(v.record));
      await tester.pumpAndSettle();
      expect(find.byType(AddVaccinationScreen), findsOne);
      final form = tester.widget<AddVaccinationScreen>(find.byType(AddVaccinationScreen));
      expect((form.vaccine, form.dose), ('Test Beta', 2), reason: 'Record prefills the dose that is due');
      expect(find.widgetWithText(TextField, 'Test Beta'), findsOne);
    });

    testWidgets('the add form saves a dose for the member, not the active profile', (tester) async {
      final state = familyState();
      final v = state.strings.vacc;
      final kid = await seedFirst('Test Kid');
      final c = await pump(tester, AddVaccinationScreen(id: kid.id), state);

      final save = find.widgetWithText(PButton, v.save);
      expect(tester.widget<PButton>(save).onTap, isNull, reason: 'no vaccine name yet');
      await tester.enterText(find.byType(TextField).first, 'Test Gamma');
      await tester.tap(find.text('3'));
      await tester.enterText(find.byType(TextField).last, 'Test Clinic');
      await tester.pump();
      expect(tester.widget<PButton>(save).onTap, isNotNull);
      await tester.tap(save);
      await tester.pumpAndSettle();

      final stored = await c.read(vaccinationsDataSourceProvider).findAll(scope: kid.id);
      expect(stored.single.vaccine, 'Test Gamma');
      expect(stored.single.doseNumber, 3);
      expect(stored.single.clinic, 'Test Clinic');
      expect(stored.single.administeredOn, DateTime.utc(today.year, today.month, today.day));
      expect(stored.single.nextDueOn, isNull);
      expect(await c.read(vaccinationsDataSourceProvider).findAll(), isEmpty, reason: 'self has no doses');
    });
  });

  group('Growth', () {
    testWidgets('adds entries newest first; either number on its own is enough', (tester) async {
      final state = familyState();
      final g = state.strings.growth;
      final kid = await seedFirst('Test Kid');
      final c = await pump(tester, GrowthScreen(id: kid.id), state);
      expect(find.text(g.empty), findsOne);

      final add = find.widgetWithText(PButton, g.add);
      expect(tester.widget<PButton>(add).onTap, isNull);
      await c.read(recordGrowthEntryUseCaseProvider)(
          measuredOn: daysFromToday(-30), weightKg: 12, heightCm: 88, now: DateTime.now(), profileId: kid.id);
      await tester.enterText(find.byType(TextField).first, '12,5');
      await tester.pump();
      await tester.tap(add);
      await tester.pumpAndSettle();

      expect(find.text(g.empty), findsNothing);
      expect(find.text(g.kg('12.5')), findsOne);
      expect(find.text('—'), findsOne, reason: 'no height on the new entry');
      expect(find.text(g.cm('88')), findsOne);
      final log = await c.read(growthLogDataSourceProvider).findAll(scope: kid.id);
      expect([for (final e in log) e.weightKg], [12.5, 12.0]);
      expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, isEmpty,
          reason: 'the form clears after adding');
    });

    testWidgets('an out-of-range number is refused with a message', (tester) async {
      final state = familyState();
      final kid = await seedFirst('Test Kid');
      final c = await pump(tester, GrowthScreen(id: kid.id), state);
      await tester.enterText(find.byType(TextField).at(1), '900');
      await tester.pump();
      await tester.tap(find.widgetWithText(PButton, state.strings.growth.add));
      await tester.pumpAndSettle();
      expect(find.text(state.strings.growth.invalid(state.gender)), findsOne);
      expect(await c.read(growthLogDataSourceProvider).findAll(scope: kid.id), isEmpty);
    });
  });

  testWidgets('Arabic: the screens lay out right to left in the patient\'s own words', (tester) async {
    final state = familyState()..setLang(LanguageCode.ar);
    final kid = await seedFirst('Test Kid');
    final c = await pump(tester, VaccinationsScreen(id: kid.id), state);
    expect(find.text('لا تطعيمات مسجّلة بعد'), findsOne);
    expect(Directionality.of(tester.element(find.text(state.strings.vacc.title))), TextDirection.rtl);

    await dose(c, kid.id, 'Test Alpha', 1, given: daysFromToday(-60), next: daysFromToday(-3));
    await tester.pumpAndSettle();
    expect(find.text('Test Alpha · الجرعة 2'), findsOne);
    expect(tester.takeException(), isNull);
  });

  group('parseMeasure / formatMeasure', () {
    test('reads Latin or Arabic-Indic digits with a point, comma or Arabic separator', () {
      expect(parseMeasure('12.5'), 12.5);
      expect(parseMeasure(' 12,5 '), 12.5);
      expect(parseMeasure('١٢٫٥'), 12.5);
      expect(parseMeasure('۹۸'), 98);
      expect(parseMeasure(''), isNull);
      expect(parseMeasure('1.2.3'), isNull);
    });

    test('drops trailing zeros', () {
      expect(formatMeasure(12), '12');
      expect(formatMeasure(9.85), '9.85');
      expect(formatMeasure(10.50), '10.5');
    });
  });
}
