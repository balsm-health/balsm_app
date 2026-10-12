import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/screens/feedback_sheet.dart';
import 'package:app/balsm_app/tokens.dart';
import 'package:app/balsm_app/widgets/balsm_mark.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// `feedback.jsx` — the five-mark rating.
///
/// A lit mark keeps the brand mark's five hues; only the unlit wash is a flat
/// ink fill. Two deliberate departures from the design: it flattens a lit mark
/// to one gold, and it prints the score as "N of 5" under the row. Neither is
/// followed — the word label (Rough … Great) is the only readout.
void main() {
  Future<PatientAppState> pump(WidgetTester tester, {bool ar = false}) async {
    final state = PatientAppState();
    if (ar) state.setLang(LanguageCode.ar);
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(ProviderScope(
      child: AppScope(
        state: state,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(builder: (c) => TextButton(onPressed: () => showFeedbackSheet(c), child: const Text('open'))),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return state;
  }

  Iterable<ColorFilter> markFilters(WidgetTester tester) =>
      tester.widgetList<ColorFiltered>(find.byType(ColorFiltered)).map((w) => w.colorFilter);

  testWidgets('every mark starts unlit, and the prompt stands in for a score', (tester) async {
    final s = await pump(tester);
    expect(find.text(s.strings.feedback.fb_rate_q), findsOne);
    // All five marks wear the flat ink wash.
    const ink = ColorFilter.mode(T.ink200, BlendMode.srcIn);
    expect(markFilters(tester).where((f) => f == ink).length, 5);
  });

  testWidgets('picking a score leaves that many marks in full colour', (tester) async {
    await pump(tester);
    // All five start unlit, so every mark is wrapped in the ink filter.
    expect(markFilters(tester).length, 5);
    await tester.tap(find.byType(ColorFiltered).at(2)); // the third mark
    await tester.pumpAndSettle();

    // A lit mark drops the filter entirely and paints the brand's five hues;
    // only the two still-unlit ones keep the flat ink wash.
    const ink = ColorFilter.mode(T.ink200, BlendMode.srcIn);
    final filters = markFilters(tester).toList();
    expect(filters.length, 2, reason: 'three lit marks are unfiltered');
    expect(filters.every((f) => f == ink), isTrue, reason: 'the unlit two stay flat ink');
    expect(find.byType(BalsmFlower), findsNWidgets(5), reason: 'still five marks');
  });

  testWidgets('the word label is the readout, not a printed number', (tester) async {
    final s = await pump(tester);
    await tester.tap(find.byType(ColorFiltered).at(3));
    await tester.pumpAndSettle();
    expect(find.text(s.strings.feedback.fb_r4), findsOne);
    // The design's "N of 5" line is deliberately absent.
    expect(find.textContaining('of 5'), findsNothing);
    expect(find.text('4'), findsNothing);
  });

  testWidgets('no bare digits leak into the Arabic sheet either', (tester) async {
    final s = await pump(tester, ar: true);
    await tester.tap(find.byType(ColorFiltered).first);
    await tester.pumpAndSettle();
    expect(find.text(s.strings.feedback.fb_r1), findsOne);
    expect(find.textContaining('5'), findsNothing);
  });

  testWidgets('each mark announces its own score to a screen reader', (tester) async {
    await pump(tester);
    for (var n = 1; n <= 5; n++) {
      expect(find.bySemanticsLabel('$n/5'), findsOne, reason: 'mark $n is unlabelled');
    }
  });
}
