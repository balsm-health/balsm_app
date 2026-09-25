import 'dart:math' as math;

import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/tokens.dart';
import 'package:app/balsm_app/screens/auth_flow.dart';
import 'package:app/balsm_app/screens/care_team_screen.dart';
import 'package:core/core.dart';
import 'package:disclosure/disclosure.dart'
    show DisclosureAcceptance, DisclosureDao, DisclosureId, disclosureDaoProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:profile/profile.dart' show CareProvider;
import 'package:mocktail/mocktail.dart';

class _MockDisclosureDao extends Mock implements DisclosureDao {}

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

  setUpAll(() => registerFallbackValue(const DisclosureId.value('consolidated')));

  setUp(() {
    FlavorConfig.init(
      brand: AppBrand.balsm,
      flavor: Flavor.dev,
      servers: const [ServerPreset(label: 'Local', apiBaseUrl: 'http://localhost:5050')],
    );
    disclosure = _MockDisclosureDao();
    when(() => disclosure.watchAcceptance(any(), any())).thenAnswer((_) => Stream<DisclosureAcceptance?>.value(null));
  });

  /// Every guideline, so a screen is either accessible or it is not.
  Future<void> expectAccessible(WidgetTester tester) async {
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  }

  Future<SemanticsHandle> pump(WidgetTester tester, Widget screen, {List<Override> overrides = const []}) async {
    final handle = tester.ensureSemantics();
    tester.view.physicalSize = const Size(402, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [disclosureDaoProvider.overrideWithValue(disclosure), ...overrides],
      child: MaterialApp(
        home: Material(
          type: MaterialType.transparency,
          child: AppScope(state: PatientAppState(), child: screen),
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

  testWidgets('the welcome screen', (tester) async {
    final handle = await pump(tester, const AuthRouter());
    await expectAccessible(tester);
    handle.dispose();
  });

  testWidgets('the sign-in screen', (tester) async {
    final handle = await pump(tester, const AuthRouter());
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    await expectAccessible(tester);
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
