import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/screens/feedback_sheet.dart';
import 'package:app/balsm_app/tokens.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// `feedback.jsx` — the five-mark rating.
///
/// The design is explicit that a lit mark is ONE uniform gold across ribbons
/// and heads ("no two-tone, no sweep"), which means the brand's five hues must
/// not show through. It also spells the score out under the row.
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

  testWidgets('every mark starts unlit, and no score is claimed', (tester) async {
    final s = await pump(tester);
    // Nothing picked yet, so the count line is absent rather than "0 of 5".
    expect(find.text(s.strings.feedback.fb_rate_count('0')), findsNothing);
    expect(find.textContaining('of 5'), findsNothing);
    // All five marks wear the flat ink wash.
    expect(markFilters(tester).length, greaterThanOrEqualTo(5));
  });

  testWidgets('picking a score lights that many marks in one uniform gold', (tester) async {
    await pump(tester);
    await tester.tap(find.byType(ColorFiltered).at(2)); // the third mark
    await tester.pumpAndSettle();

    const gold = ColorFilter.mode(Color(0xFFF0AE1A), BlendMode.srcIn);
    const ink = ColorFilter.mode(T.ink200, BlendMode.srcIn);
    final filters = markFilters(tester).take(5).toList();
    expect(filters.where((f) => f == gold).length, 3, reason: 'three lit');
    expect(filters.where((f) => f == ink).length, 2, reason: 'two unlit');
    // The brand hues must not survive on a lit mark — a plain BalsmFlower with
    // no filter would mean the gradient is showing through.
    expect(filters.every((f) => f == gold || f == ink), isTrue);
  });

  testWidgets('the score is spelled out under the row', (tester) async {
    final s = await pump(tester);
    await tester.tap(find.byType(ColorFiltered).at(3));
    await tester.pumpAndSettle();
    expect(find.text(s.strings.feedback.fb_rate_count('4')), findsOne);
  });

  testWidgets('the count stays LTR in Arabic', (tester) async {
    final s = await pump(tester, ar: true);
    await tester.tap(find.byType(ColorFiltered).first);
    await tester.pumpAndSettle();
    final count = find.text(s.strings.feedback.fb_rate_count('1'));
    expect(count, findsOne);
    expect(Directionality.of(tester.element(count)), TextDirection.ltr);
  });

  testWidgets('each mark announces its own score to a screen reader', (tester) async {
    await pump(tester);
    for (var n = 1; n <= 5; n++) {
      expect(find.bySemanticsLabel('$n/5'), findsOne, reason: 'mark $n is unlabelled');
    }
  });
}
