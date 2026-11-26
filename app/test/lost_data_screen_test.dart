import 'package:app/balsm_app/strings.dart';
import 'package:app/balsm_app/widgets/lost_data_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<int Function()> pump(WidgetTester tester, String lang) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: LostDataScreen(lang: lang, onStartFresh: () async => calls++),
      ),
    );
    return () => calls;
  }

  testWidgets('explains first; starting fresh takes a second, explicit confirmation', (tester) async {
    final s = stringsFor('en').boot;
    final calls = await pump(tester, 'en');

    expect(find.text(s.lost_t), findsOneWidget);
    expect(find.text(s.lost_b('Balsm')), findsOneWidget);
    expect(find.text(s.lost_confirm_yes), findsNothing);

    await tester.tap(find.text(s.lost_start));
    await tester.pump();
    expect(find.text(s.lost_confirm_t), findsOneWidget);
    expect(calls(), 0, reason: 'one tap must never move the data');

    await tester.tap(find.text(s.lost_cancel));
    await tester.pump();
    expect(find.text(s.lost_t), findsOneWidget);
    expect(calls(), 0);

    await tester.tap(find.text(s.lost_start));
    await tester.pump();
    await tester.tap(find.text(s.lost_confirm_yes));
    await tester.pump();
    expect(calls(), 1);

    // While the move runs the buttons are off, so a second tap does nothing.
    await tester.tap(find.text(s.lost_confirm_yes));
    await tester.pump();
    expect(calls(), 1);
  });

  testWidgets('Arabic reads right to left, with the Arabic app name', (tester) async {
    final s = stringsFor('ar').boot;
    await pump(tester, 'ar');

    expect(find.text(s.lost_t), findsOneWidget);
    expect(find.text(s.lost_b('بلسم')), findsOneWidget);
    expect(Directionality.of(tester.element(find.text(s.lost_t))), TextDirection.rtl);
  });

  testWidgets('fits a small phone at the largest text size without overflowing', (tester) async {
    tester.view
      ..physicalSize = const Size(320, 568)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final s = stringsFor('ar').boot;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(320, 568), textScaler: TextScaler.linear(1.3)),
        child: MaterialApp(home: LostDataScreen(lang: 'ar', onStartFresh: () async {})),
      ),
    );
    expect(tester.takeException(), isNull);
    // Taller than the screen here: the content scrolls rather than overflows.
    await tester.ensureVisible(find.text(s.lost_start));
    await tester.tap(find.text(s.lost_start));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text(s.lost_cancel));
    expect(find.text(s.lost_cancel).hitTestable(), findsOneWidget);
  });
}
