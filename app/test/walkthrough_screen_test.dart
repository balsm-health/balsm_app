import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/kit.dart';
import 'package:app/balsm_app/screens/walkthrough_screen.dart';
import 'package:app/balsm_app/widgets/language_pill.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// The onboarding walkthrough: Back beside Next from the second slide on (the
/// last included), and a Next button whose glow matches its own fill.
void main() {
  // The slide-2 demo's fixed-size tabs are wider than the test font's glyphs allow
  // (the same on the unchanged screen), which is a test-font artifact: accept that
  // overflow, and only that, so anything else still fails the test.
  void allowDemoOverflow(WidgetTester tester) {
    final e = tester.takeException();
    if (e != null) expect(e.toString(), contains('overflowed'));
  }

  // The aura loops forever, so the screen never settles: step past the slide
  // transition instead. An implicit animation starts on the frame after the
  // rebuild, so build first, then let the time pass.
  Future<void> frames(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    allowDemoOverflow(tester);
  }


  /// The width of the animated slot Back lives in (the button inside is laid out full width and clipped).
  double slot(WidgetTester tester, Finder back) =>
      tester.getSize(find.ancestor(of: back, matching: find.byType(SizedBox)).first).width;

  Future<PatientAppState> pump(WidgetTester tester) async {
    // The screen caps itself at 440dp; the slide-2 demo's tabs overflow the test font below that.
    tester.view.physicalSize = const Size(480, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final state = PatientAppState();
    await tester.pumpWidget(
      AppScope(
        state: state,
        // The shell wraps the whole app in the account's accent; so does this.
        child: AccentScope(
          accent: state.accent,
          child: const MaterialApp(home: Scaffold(body: WalkthroughScreen())),
        ),
      ),
    );
    await frames(tester);
    return state;
  }

  testWidgets('Back is hidden on the first slide, shown beside Next on the second and the last', (tester) async {
    final s = await pump(tester);
    final wt = s.strings.walkthrough;
    final back = find.widgetWithText(PButton, s.strings.common.back);

    expect(back, findsNothing, reason: 'the first slide has nowhere to go back to');
    expect(find.widgetWithText(PButton, wt.wt_next), findsOne);

    await tester.tap(find.widgetWithText(PButton, wt.wt_next));
    await frames(tester);
    expect(back, findsOne);
    expect(find.widgetWithText(PButton, wt.wt_next), findsOne);

    await tester.tap(find.widgetWithText(PButton, wt.wt_next));
    await frames(tester);
    expect(find.widgetWithText(PButton, wt.wt_start), findsOne, reason: 'the last slide offers Get started');
    expect(back, findsOne, reason: 'Back stays on the last slide');
    expect(tester.getCenter(back).dy, tester.getCenter(find.widgetWithText(PButton, wt.wt_start)).dy);
  });

  testWidgets('Back grows in beside Next rather than popping in, and leaves the same way', (tester) async {
    final s = await pump(tester);
    final wt = s.strings.walkthrough;
    final back = find.widgetWithText(PButton, s.strings.common.back);
    final nextWidth = tester.getSize(find.widgetWithText(PButton, wt.wt_next)).width;

    await tester.tap(find.widgetWithText(PButton, wt.wt_next));
    await tester.pump(); // the slide changes; Back starts at zero width
    await tester.pump(const Duration(milliseconds: 100));
    allowDemoOverflow(tester);
    final midBack = slot(tester, back);
    final midNext = tester.getSize(find.widgetWithText(PButton, wt.wt_next)).width;
    await tester.pump(const Duration(milliseconds: 400));
    final fullBack = slot(tester, back);
    final fullNext = tester.getSize(find.widgetWithText(PButton, wt.wt_next)).width;

    expect(midBack, inExclusiveRange(0, fullBack), reason: 'Back is part-way in after 100ms');
    expect(midNext, inExclusiveRange(fullNext, nextWidth), reason: 'Next gives up its width as Back arrives');
    expect(fullBack, greaterThan(0));

    await tester.tap(back);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(back, findsOne, reason: 'still leaving after 100ms');
    expect(slot(tester, back), lessThan(fullBack));
    await tester.pump(const Duration(milliseconds: 400));
    expect(back, findsNothing);
  });

  testWidgets('Next becomes Get started in the same button: only the label cross-fades', (tester) async {
    final s = await pump(tester);
    final wt = s.strings.walkthrough;
    await tester.tap(find.widgetWithText(PButton, wt.wt_next));
    await frames(tester);

    final before = tester.element(find.byType(PButton).last);
    await tester.tap(find.widgetWithText(PButton, wt.wt_next));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    allowDemoOverflow(tester);

    expect(find.text(wt.wt_next), findsOne, reason: 'the old label is still fading out');
    expect(find.text(wt.wt_start), findsOne, reason: 'the new label is already fading in');
    expect(identical(tester.element(find.byType(PButton).last), before), isTrue, reason: 'the button is not rebuilt');

    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(wt.wt_next), findsNothing);
    expect(find.text(wt.wt_start), findsOne);
  });

  testWidgets('the language pill switches the walkthrough between English and Arabic', (tester) async {
    final s = await pump(tester);
    expect(s.lang, LanguageCode.en);
    final english = s.strings.walkthrough.wt_title_1;
    expect(find.text(english), findsOne);
    expect(find.text(LanguageCode.ar.nativeName), findsOne, reason: 'it names the language it switches to');

    await tester.tap(find.byType(LanguagePill));
    await frames(tester);

    expect(s.lang, LanguageCode.ar);
    expect(s.strings.walkthrough.wt_title_1, isNot(english));
    expect(find.text(s.strings.walkthrough.wt_title_1), findsOne, reason: 'the slide is now in Arabic');
    expect(find.text(LanguageCode.en.nativeName), findsOne);

    await tester.tap(find.byType(LanguagePill));
    await frames(tester);
    expect(s.lang, LanguageCode.en);
  });

  testWidgets('with reduce-motion on, Back appears at once', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final s = await pump(tester);

    await tester.tap(find.widgetWithText(PButton, s.strings.walkthrough.wt_next));
    await tester.pump();
    await tester.pump();
    expect(find.widgetWithText(PButton, s.strings.common.back), findsOne);
  });

  testWidgets('Back returns to the previous slide', (tester) async {
    final s = await pump(tester);
    final wt = s.strings.walkthrough;

    await tester.tap(find.widgetWithText(PButton, wt.wt_next));
    await frames(tester);
    await tester.tap(find.widgetWithText(PButton, s.strings.common.back));
    await frames(tester);

    expect(find.text(wt.wt_title_1), findsOne);
    expect(find.widgetWithText(PButton, s.strings.common.back), findsNothing);
  });

  testWidgets("Next glows in the app accent, whatever the slide's own hue", (tester) async {
    final s = await pump(tester);
    final wt = s.strings.walkthrough;

    for (var slide = 0; slide < 3; slide++) {
      final label = slide == 2 ? wt.wt_start : wt.wt_next;
      final box = tester.widget<Container>(
        find.descendant(of: find.widgetWithText(PButton, label), matching: find.byType(Container)).first,
      );
      final deco = box.decoration! as BoxDecoration;
      expect(deco.color, s.accent.main, reason: 'slide ${slide + 1}: the fill');
      expect(deco.boxShadow, s.accent.boxShadow, reason: "slide ${slide + 1}: the glow is the fill's, not the slide's");
      if (slide < 2) {
        await tester.tap(find.widgetWithText(PButton, label));
        await frames(tester);
      }
    }
  });
}
