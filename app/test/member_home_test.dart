import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/family/profile_family_members.dart';
import 'package:app/balsm_app/flags.dart';
import 'package:app/balsm_app/kit.dart';
import 'package:app/balsm_app/screens/family/family_kit.dart';
import 'package:app/balsm_app/screens/family/vaccinations_screen.dart';
import 'package:app/balsm_app/screens/home_screen.dart';
import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:family/family.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Home while a family member is the active profile (Mother and Child canvas,
/// "06 Member profile"): back + "Family" header, the member's head and tiles.
/// Every name here is invented by the test.
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

  /// Pumps Home with a three-year-old son as the active profile.
  Future<ProviderContainer> pumpHome(WidgetTester tester, PatientAppState state) async {
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
                  displayName: 'Test Kid',
                  relationship: Relationship.child,
                  dateOfBirth: DateTime(today.year - 3, 1, 1),
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
          home: const Scaffold(body: HomeScreen()),
        ),
      ),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await settle(tester);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await settle(tester);
    return c;
  }

  Finder roundBtn(String label) => find.byWidgetPredicate((w) => w is RoundBtn && w.semanticLabel == label);

  testWidgets('shows back + Family, the member head and the child tiles in the canvas order', (tester) async {
    final state = familyState();
    await pumpHome(tester, state);
    final f = state.strings.family;

    expect(find.descendant(of: find.byType(AppBarRow), matching: find.text(f.title)), findsOneWidget);
    expect(roundBtn(state.strings.home.member_back), findsOneWidget);
    expect(find.byType(HomeGreeting), findsNothing, reason: 'the greeting names the account holder, not the member');
    expect(find.text('Test Kid'), findsOneWidget);

    final titles = tester.widgetList<FamilyTile>(find.byType(FamilyTile)).map((t) => t.title).toList();
    expect(titles.take(4), [f.tile_card, state.strings.vacc.title, state.strings.growth.title, f.tile_records]);
    expect(titles, containsAll([f.tile_medical, f.tile_trends, f.tile_meds]));
    // No blood type yet: the card line has no leading dash.
    expect(find.text(f.no_allergies), findsOneWidget);
  });

  testWidgets('the Vaccinations tile opens the member\'s vaccinations', (tester) async {
    final state = familyState();
    await pumpHome(tester, state);
    await tester.tap(find.text(state.strings.vacc.title));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await settle(tester);
    expect(find.byType(VaccinationsScreen), findsOneWidget);
  });

  testWidgets('back returns Home to the account holder\'s own profile', (tester) async {
    final state = familyState();
    final c = await pumpHome(tester, state);
    final self = await c.read(selfProfileIdProvider.future);
    await tester.tap(roundBtn(state.strings.home.member_back));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await settle(tester);
    expect(c.read(currentProfileIdProvider), self);
    expect(find.byType(HomeGreeting), findsOneWidget);
    expect(find.text('Test Kid'), findsNothing);
  });

  testWidgets('Arabic: right to left, in Arabic', (tester) async {
    final state = familyState()..setLang(LanguageCode.ar);
    await pumpHome(tester, state);
    final f = state.strings.family;
    expect(find.descendant(of: find.byType(AppBarRow), matching: find.text(f.title)), findsOneWidget);
    expect(find.text(f.tile_card), findsOneWidget);
    expect(roundBtn('العودة إلى ملفك'), findsOneWidget);
    expect(Directionality.of(tester.element(find.text(f.tile_card))), TextDirection.rtl);
    expect(tester.takeException(), isNull);
  });
}
