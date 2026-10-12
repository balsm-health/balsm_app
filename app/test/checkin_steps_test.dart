import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/screens/checkin_shared.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

/// `UX Enhancement Screens.html` — "Full check-in · DS Steps": the numbered
/// step row that replaced the single progress bar.
void main() {
  Future<PatientAppState> pump(
    WidgetTester tester,
    List<String> steps,
    int current, {
    Size window = const Size(390, 812),
  }) async {
    final state = PatientAppState();
    tester.view.physicalSize = window;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(
      home: AppScope(
        state: state,
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: CheckInSteps(s: state, steps: steps, current: current),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return state;
  }

  testWidgets('done steps tick, the rest keep their number', (tester) async {
    await pump(tester, const ['mood', 'bp', 'glucose', 'symptoms'], 1);
    // Step 1 is behind us.
    expect(find.byIcon(LucideIcons.check), findsOne);
    // The current and upcoming ones show 2, 3, 4 — never 1, which is ticked.
    expect(find.text('2'), findsOne);
    expect(find.text('3'), findsOne);
    expect(find.text('4'), findsOne);
    expect(find.text('1'), findsNothing);
  });

  testWidgets('the first step has nothing ticked', (tester) async {
    await pump(tester, const ['mood', 'bp', 'glucose'], 0);
    expect(find.byIcon(LucideIcons.check), findsNothing);
    expect(find.text('1'), findsOne);
  });

  testWidgets('the last step ticks everything before it', (tester) async {
    await pump(tester, const ['mood', 'bp', 'glucose'], 2);
    expect(find.byIcon(LucideIcons.check), findsExactly(2));
    expect(find.text('3'), findsOne);
  });

  testWidgets('captions name each step', (tester) async {
    final s = await pump(tester, const ['mood', 'bp', 'glucose', 'symptoms'], 0);
    expect(find.text(s.strings.checkin.st_mood), findsOne);
    expect(find.text(s.strings.checkin.st_bp), findsOne);
    expect(find.text(s.strings.checkin.st_glucose), findsOne);
    expect(find.text(s.strings.checkin.st_symptoms), findsOne);
  });

  testWidgets('a long check-in drops the captions rather than crushing them', (tester) async {
    final s = await pump(
      tester,
      const ['mood', 'bp', 'glucose', 'weight', 'spo2', 'pain', 'symptoms'],
      0,
    );
    expect(find.text(s.strings.checkin.st_mood), findsNothing);
    // The discs stay, so progress is still readable.
    expect(find.text('7'), findsOne);
    expect(tester.takeException(), isNull);
  });

  testWidgets('it fits a narrow phone with captions', (tester) async {
    await pump(tester, const ['mood', 'bp', 'glucose', 'symptoms'], 1, window: const Size(360, 780));
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unknown step id falls back to the id, never throws', (tester) async {
    await pump(tester, const ['mood', 'not_a_metric'], 0);
    expect(find.text('not_a_metric'), findsOne);
  });
}
