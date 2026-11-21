import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/family/profile_family_members.dart';
import 'package:app/balsm_app/flags.dart';
import 'package:app/balsm_app/kit.dart';
import 'package:app/balsm_app/screens/family/family_kit.dart';
import 'package:app/balsm_app/screens/family/member_screen.dart';
import 'package:app/balsm_app/screens/family/vaccinations_screen.dart';
import 'package:app/balsm_app/screens/home_screen.dart';
import 'package:app/balsm_app/screens/home_widgets.dart';
import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:family/family.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Home while a family member is the active profile (home-mc.jsx
/// `HomeMemberV2`): the account holder's header, then the member's check-in,
/// latest readings, six shortcuts and recent logs. The member profile screen
/// keeps the canvas "06 Member profile" head and tiles. Every name here is
/// invented by the test.
void main() {
  const user = UserId.value('u-member-home-test');
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  final today = DateTime.now();

  /// Home has looping animations, so pumpAndSettle would never return.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  PatientAppState familyState() {
    final flags = FeatureFlags(flags: AppFlags.all, allowOverrides: true)..setOverride(AppFlags.motherChild, true);
    return PatientAppState()..attachFlags(flags);
  }

  /// Pumps [screen] (Home by default) with a three-year-old son — or, with
  /// [adult], a forty-year-old father — as the active profile.
  Future<(ProviderContainer, FamilyMember)> pumpHome(WidgetTester tester, PatientAppState state,
      {bool adult = false, Widget Function(FamilyMember m)? screen}) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final c = ProviderContainer(overrides: [
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
    addTearDown(c.dispose);
    final kid = (await c.read(saveFamilyMemberUseCaseProvider).add(
              MemberDraft(
                  displayName: adult ? 'Test Elder' : 'Test Kid',
                  relationship: adult ? Relationship.parent : Relationship.child,
                  dateOfBirth: DateTime(today.year - (adult ? 40 : 3), 1, 1),
                  sex: Sex.male),
              userId: user,
              now: DateTime.now(),
            ))
        .value;
    await c.read(activeProfileSwitcherProvider).select(kid.id);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: AppScope(
        state: state,
        child: MaterialApp(
          builder: (_, child) => Directionality(textDirection: state.dir, child: child!),
          home: Scaffold(body: screen == null ? const HomeScreen() : SingleChildScrollView(child: screen(kid))),
        ),
      ),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await settle(tester);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await settle(tester);
    return (c, kid);
  }

  List<String> shortcutLabels(WidgetTester tester) =>
      tester.widgetList<HomeShortcutTile>(find.byType(HomeShortcutTile)).map((t) => t.label).toList();

  testWidgets('a child: the header, check-in, readings, shortcuts and recent logs of the prototype', (tester) async {
    final state = familyState();
    final (_, kid) = await pumpHome(tester, state);
    final h = state.strings.home;
    final f = state.strings.family;
    final name = kid.shortName;

    // The account holder's own header; the profile bar says whose Home it is.
    expect(find.byType(HomeGreeting), findsOneWidget);
    expect(find.byType(RoundBtn), findsNothing, reason: 'no back button: this is Home, not the member screen');
    expect(find.byType(FamilyTile), findsNothing, reason: 'the member-profile tiles belong to the member screen');

    expect(find.text(h.member_ci_q(name)), findsOneWidget);
    expect(find.text(h.member_ci_note_child(state.gender)), findsOneWidget);
    expect(find.text(h.member_ci_cta(state.gender, name)), findsOneWidget);
    expect(find.text(h.hero_time), findsNothing);

    expect(tester.widgetList<HomeSectionHead>(find.byType(HomeSectionHead)).map((w) => w.title),
        [state.strings.checkin.latest, state.strings.common.recent]);
    expect(find.text(state.strings.profile.m_weight), findsOneWidget);
    expect(find.text(h.m_height), findsOneWidget);
    expect(find.text(state.strings.profile.m_bp), findsNothing, reason: "a child's readings start with weight");

    expect(shortcutLabels(tester), [
      f.tile_card,
      f.tile_medical,
      h.sc_records,
      f.tile_meds,
      state.strings.vacc.title,
      state.strings.growth.title,
    ]);
    // Nothing logged: no rows, and the empty line names them.
    expect(find.text(h.member_recent_empty(name)), findsOneWidget);
    // Hidden against the account holder's own Home.
    expect(find.text(state.strings.care.map_nearby), findsNothing);
    expect(find.text(state.strings.profile.p_care), findsNothing);
  });

  testWidgets('an adult: blood pressure first, then trends and full profile shortcuts', (tester) async {
    final state = familyState();
    final (_, elder) = await pumpHome(tester, state, adult: true);
    final h = state.strings.home;
    final f = state.strings.family;
    expect(find.text(state.strings.profile.m_bp), findsOneWidget);
    expect(find.text(h.member_ci_note(state.gender, elder.shortName)), findsOneWidget);
    expect(shortcutLabels(tester),
        [f.tile_card, f.tile_medical, h.sc_records, f.tile_meds, f.tile_trends, h.sc_full_profile]);
  });

  testWidgets("the Vaccinations shortcut opens the member's vaccinations", (tester) async {
    final state = familyState();
    await pumpHome(tester, state);
    await tester.tap(find.text(state.strings.vacc.title));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await settle(tester);
    expect(find.byType(VaccinationsScreen), findsOneWidget);
  });

  testWidgets('Arabic: right to left, the member named in Arabic copy', (tester) async {
    final state = familyState()..setLang(LanguageCode.ar);
    final (_, kid) = await pumpHome(tester, state);
    final q = find.text('كيف حال ${kid.shortName} اليوم؟');
    expect(q, findsOneWidget);
    expect(find.text('سجّل لـ${kid.shortName}'), findsOneWidget);
    expect(Directionality.of(tester.element(q)), TextDirection.rtl);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the member profile screen keeps the canvas head and tiles', (tester) async {
    final state = familyState();
    await pumpHome(tester, state, screen: (m) => MemberBody(member: m));
    final f = state.strings.family;
    expect(find.byType(MemberAvatar), findsOneWidget);
    expect(find.text('Test Kid'), findsOneWidget);
    final titles = tester.widgetList<FamilyTile>(find.byType(FamilyTile)).map((t) => t.title).toList();
    expect(titles.take(4), [f.tile_card, state.strings.vacc.title, state.strings.growth.title, f.tile_records]);
    expect(titles, containsAll([f.tile_medical, f.tile_trends, f.tile_meds]));
    expect(find.text(f.no_allergies), findsOneWidget);
  });
}
