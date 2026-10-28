import 'dart:math' as math;

import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/routes.dart';
import 'package:app/balsm_app/tokens.dart';
import 'package:app/balsm_app/screens/auth_flow.dart';
import 'package:app/balsm_app/screens/care_team_screen.dart';
import 'package:auth/auth.dart';
import 'package:core/core.dart';
import 'package:disclosure/disclosure.dart'
    show DisclosureAcceptance, DisclosureDao, DisclosureId, disclosureDaoProvider;
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:profile/profile.dart' show CareProvider;
import 'package:mocktail/mocktail.dart';

class _MockDisclosureDao extends Mock implements DisclosureDao {}

class _MockOfflineAccountService extends Mock implements OfflineAccountService {}

/// Flutter's own accessibility guidelines, run against real screens.
///
/// A patient using TalkBack or VoiceOver meets the same app everyone else
/// does, or they do not get to use it. These four checks are the part a
/// machine can hold: every tap target announces something, is big enough to
/// hit, and every label is readable against what is behind it.
///
/// They are a floor, not a certificate — a screen can pass all four and still
/// be incoherent read aloud. The manual pass with a screen reader is what
/// proves the flow.
void main() {
  late _MockDisclosureDao disclosure;
  late _MockOfflineAccountService offline;

  setUpAll(() => registerFallbackValue(const DisclosureId.value('consolidated')));

  setUp(() {
    FlavorConfig.init(
      brand: AppBrand.balsm,
      flavor: Flavor.dev,
      servers: const [ServerPreset(label: 'Local', apiBaseUrl: 'http://localhost:5050')],
    );
    disclosure = _MockDisclosureDao();
    when(() => disclosure.watchAcceptance(any(), any())).thenAnswer((_) => Stream<DisclosureAcceptance?>.value(null));
    offline = _MockOfflineAccountService();
    when(() => offline.lockout()).thenAnswer((_) async => null);
  });

  /// Every guideline, so a screen is either accessible or it is not.
  Future<void> expectAccessible(WidgetTester tester) async {
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  }

  Future<SemanticsHandle> pump(WidgetTester tester, Widget screen,
      {List<Override> overrides = const [], String? route}) async {
    final handle = tester.ensureSemantics();
    tester.view.physicalSize = const Size(402, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = PatientAppState();
    if (route != null) state.route = route;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        disclosureDaoProvider.overrideWithValue(disclosure),
        offlineAccountServiceProvider.overrideWithValue(offline),
        ...overrides,
      ],
      child: MaterialApp(
        home: Material(
          type: MaterialType.transparency,
          child: AppScope(state: state, child: screen),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return handle;
  }

  // ── The tokens themselves ───────────────────────────────────────────────
  // A screen test only catches what that screen happens to paint. These are
  // the values every screen draws from, checked at the source.

  double contrast(Color a, Color b) {
    double lum(Color c) {
      double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
      return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
    }

    final la = lum(a);
    final lb = lum(b);
    return ((la > lb ? la : lb) + 0.05) / ((la > lb ? lb : la) + 0.05);
  }

  test('every text ink clears 4.5:1 on the cream ground', () {
    for (final (name, ink) in [('fg1', T.fg1), ('fg2', T.fg2), ('fg3', T.fg3), ('fg4', T.fg4)]) {
      expect(contrast(ink, T.cream50), greaterThanOrEqualTo(4.5), reason: '$name is body text somewhere');
    }
  });

  test('a filled button picks text that can be read on it', () {
    // White was assumed everywhere; on mint it measures 2.28:1.
    for (final fill in [T.hueMint600, T.hueAqua600, T.hueEmerald600, T.sun500, T.danger, T.hueViolet600]) {
      expect(contrast(T.onFill(fill), fill), greaterThanOrEqualTo(4.5));
    }
  });

  testWidgets('the code boxes are one field, not six blank containers', (tester) async {
    // Six painted boxes announced as six unlabelled nodes, which is what a
    // screen reader met before: no name, no way to know how many digits had
    // landed, no way to tell it was an input at all.
    final handle = await pump(tester, const AuthRouter());
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'patient@example.test');
    await tester.enterText(find.byType(TextField).last, 'a-real-password');
    await tester.pump();

    // Straight to the code step through the router's own state.
    AppScope.of(tester.element(find.text('Send code'))).go(AppRoutes.otp);
    await tester.pumpAndSettle();

    final field = find.bySemanticsLabel('Verification code');
    expect(field, findsOneWidget);
    // How many digits have landed is the value, not the label — a screen
    // reader reads it back as the field's contents.
    expect(tester.getSemantics(field).value, contains('0 of 6'));
    handle.dispose();
  });

  testWidgets('the welcome screen', (tester) async {
    final handle = await pump(tester, const AuthRouter());
    await expectAccessible(tester);
    handle.dispose();
  });

  for (final button in ['Sign in', 'Create an account', 'Use on this device only']) {
    testWidgets('the credential screen after "$button"', (tester) async {
      final handle = await pump(tester, const AuthRouter());
      await tester.tap(find.text(button));
      await tester.pumpAndSettle();

      await expectAccessible(tester);
      handle.dispose();
    });
  }

  testWidgets('the unlock screen', (tester) async {
    final handle = await pump(tester, const AuthRouter(), route: AppRoutes.unlock);
    await expectAccessible(tester);
    handle.dispose();
  });

  testWidgets('the merge-or-discard screen', (tester) async {
    final handle = await pump(tester, const AuthRouter(), route: AppRoutes.mergeOrDiscard);
    await expectAccessible(tester);
    handle.dispose();
  });

  testWidgets('the sign-in ⇄ sign-up switch is reachable by screen reader', (tester) async {
    // The tap-target-size guideline above only checks geometry — a node with
    // no SemanticsAction.tap at all would still pass it, silently. This test
    // is what actually proves TalkBack/VoiceOver can activate the link.
    final handle = await pump(tester, const AuthRouter());
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    final node = tester.getSemantics(find.bySemanticsLabel('Create an account'));
    expect(node, matchesSemantics(isButton: true, hasTapAction: true, label: 'Create an account'));

    // The activation a screen reader's gesture sends — not a raw widget tap.
    // `rootPipelineOwner`'s owner doesn't hold this node's id in this test
    // harness (the action silently no-ops); `pipelineOwner` is what actually
    // owns the rendered semantics tree here, deprecated or not.
    // ignore: deprecated_member_use
    tester.binding.pipelineOwner.semanticsOwner!.performAction(node.id, SemanticsAction.tap);
    await tester.pumpAndSettle();

    expect(find.text('Send code'), findsOneWidget, reason: 'the semantics action must switch to sign-up');
    handle.dispose();
  });

  testWidgets('an empty care team', (tester) async {
    final handle = await pump(
      tester,
      const CareTeamScreen(),
      overrides: [careTeamProvider.overrideWith((ref) => Stream.value(const <CareProvider>[]))],
    );

    await expectAccessible(tester);
    handle.dispose();
  });
}
