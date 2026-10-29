import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/screens/metric_log.dart';
import 'package:app/balsm_app/screens/quick_log.dart';
import 'package:app/balsm_app/kit.dart';
import 'package:app/balsm_app/screens/checkin_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

/// quicklog.jsx `Sheet` — Save in the header and at the bottom, Cancel, and a
/// discard prompt before unsaved input is thrown away.
void main() {
  late PatientAppState s;

  Future<void> openMood(WidgetTester tester) async {
    s = PatientAppState();
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      child: AppScope(
        state: s,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(child: TextButton(onPressed: () => showQuickLog(context), child: const Text('open'))),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.strings.profile.m_mood));
    await tester.pumpAndSettle();
  }

  RoundBtn saveBtn(WidgetTester tester) => tester.widget<RoundBtn>(find.widgetWithIcon(RoundBtn, LucideIcons.check));
  Future<void> pickMood(WidgetTester tester) async {
    await tester.tap(find.byType(MoodCell).at(3));
    await tester.pumpAndSettle();
  }

  testWidgets('Save waits for a complete entry, with a hint until then', (tester) async {
    await openMood(tester);
    expect(find.byIcon(LucideIcons.x), findsNothing);
    expect(saveBtn(tester).onTap, isNull);
    expect(find.text(s.strings.checkin.ql_save), findsOneWidget);
    expect(find.text(s.strings.checkin.ql_save_hint), findsOneWidget);
    expect(find.text(s.strings.common.cancel), findsOneWidget);

    await pickMood(tester);
    expect(saveBtn(tester).onTap, isNotNull);
    expect(find.text(s.strings.checkin.ql_save_hint), findsNothing);
  });

  testWidgets('system back steps out of a flow, then closes the sheet', (tester) async {
    await openMood(tester);
    final nav = tester.state<NavigatorState>(find.byType(Navigator).last);
    await nav.maybePop();
    await tester.pumpAndSettle();
    expect(find.byType(MetricLog), findsNothing);
    expect(find.text(s.strings.checkin.ql_title), findsOneWidget);

    await nav.maybePop();
    await tester.pumpAndSettle();
    expect(find.text(s.strings.checkin.ql_title), findsNothing);
  });

  testWidgets('system back with the prompt open dismisses only the prompt', (tester) async {
    await openMood(tester);
    await pickMood(tester);
    final nav = tester.state<NavigatorState>(find.byType(Navigator).last);
    await nav.maybePop();
    await tester.pumpAndSettle();
    expect(find.text(s.strings.checkin.ql_discard_title), findsOneWidget);

    await nav.maybePop();
    await tester.pumpAndSettle();
    expect(find.text(s.strings.checkin.ql_discard_title), findsNothing);
    expect(find.byType(MetricLog), findsOneWidget);
  });

  testWidgets('back with nothing entered returns straight to the list', (tester) async {
    await openMood(tester);
    await tester.tap(find.text(s.strings.common.cancel));
    await tester.pumpAndSettle();
    expect(find.text(s.strings.checkin.ql_discard_title), findsNothing);
    expect(find.text(s.strings.checkin.ql_title), findsOneWidget);
  });

  testWidgets('back with input asks first; Keep editing stays, Discard returns', (tester) async {
    await openMood(tester);
    await pickMood(tester);

    await tester.tap(find.text(s.strings.common.cancel));
    await tester.pumpAndSettle();
    expect(find.text(s.strings.checkin.ql_discard_title), findsOneWidget);

    await tester.tap(find.text(s.strings.checkin.ql_keep_editing));
    await tester.pumpAndSettle();
    expect(find.text(s.strings.checkin.ql_discard_title), findsNothing);
    expect(saveBtn(tester).onTap, isNotNull);

    await tester.tap(find.text(s.strings.common.cancel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.strings.checkin.ql_discard));
    await tester.pumpAndSettle();
    expect(find.text(s.strings.checkin.ql_title), findsOneWidget);
    expect(find.byType(MetricLog), findsNothing);
  });

  testWidgets('dismissing the sheet with input asks instead of closing', (tester) async {
    await openMood(tester);
    await pickMood(tester);

    // System back (and the barrier) go through maybePop.
    await tester.state<NavigatorState>(find.byType(Navigator).last).maybePop();
    await tester.pumpAndSettle();
    expect(find.text(s.strings.checkin.ql_discard_title), findsOneWidget);
    expect(find.byType(MetricLog), findsOneWidget);

    await tester.tap(find.text(s.strings.checkin.ql_keep_editing));
    await tester.pumpAndSettle();

    // Drag the sheet down by its grab handle.
    await tester.drag(find.byType(SheetGrab), const Offset(0, 500));
    await tester.pumpAndSettle();
    expect(find.byType(MetricLog), findsOneWidget);
    expect(find.text(s.strings.checkin.ql_discard_title), findsOneWidget);

    await tester.tap(find.text(s.strings.checkin.ql_discard));
    await tester.pumpAndSettle();
    expect(find.text(s.strings.checkin.ql_title), findsNothing);
  });

  testWidgets('dragging the sheet down with nothing entered closes it', (tester) async {
    await openMood(tester);
    await tester.drag(find.byType(SheetGrab), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(find.byType(MetricLog), findsNothing);
    expect(find.text(s.strings.checkin.ql_title), findsNothing);
  });
}
