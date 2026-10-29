import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/screens/metric_log.dart';
import 'package:app/balsm_app/widgets/num_pad.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:self_report/self_report.dart';

/// quicklog.jsx `QuickPulse`: type the rate, or tap each beat for 15 s and
/// the rate is the count × 4. Only 30–220 bpm saves.
void main() {
  late PatientAppState s;
  late List<(MetricLogCapture, bool)> seen;

  Future<void> pump(WidgetTester tester) async {
    s = PatientAppState();
    seen = [];
    tester.view.physicalSize = const Size(402, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      child: AppScope(
        state: s,
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MetricLog(
                metric: CheckInMetric.heartRate,
                s: s,
                host: MetricLogHost.standalone,
                onChanged: (c, {required bool valid}) => seen.add((c, valid)),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String n) async {
    for (final d in n.split('')) {
      await tester.tap(find.descendant(of: find.byType(NumPad), matching: find.text(d)));
      await tester.pump();
    }
  }

  testWidgets('a typed rate in range saves as heart rate', (tester) async {
    await pump(tester);
    await type(tester, '72');
    final (capture, valid) = seen.last;
    expect(valid, isTrue);
    expect(capture.vitals.heartRate, 72);
    expect(capture.summary, s.strings.checkin.reading_unit('72', s.strings.checkin.unit_bpm));
  });

  for (final n in ['25', '230']) {
    testWidgets('$n bpm is out of range and does not save', (tester) async {
      await pump(tester);
      await type(tester, n);
      expect(seen.last.$2, isFalse);
      expect(seen.last.$1.vitals.heartRate, isNull);
    });
  }

  testWidgets('counting 18 beats in 15 s gives 72 bpm', (tester) async {
    await pump(tester);
    await tester.tap(find.text(s.strings.checkin.pulse_count));
    await tester.pumpAndSettle();
    expect(find.text(s.strings.checkin.pulse_start), findsOneWidget);

    final circle = find.byIcon(LucideIcons.heart);
    for (var i = 0; i < 18; i++) {
      await tester.tap(circle);
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Still counting: nothing to save yet.
    expect(seen.last.$2, isFalse);
    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();

    expect(find.byType(NumPad), findsOneWidget);
    expect(seen.last.$2, isTrue);
    expect(seen.last.$1.vitals.heartRate, 72);
  });

  testWidgets('"Type the number instead" leaves the count', (tester) async {
    await pump(tester);
    await tester.tap(find.text(s.strings.checkin.pulse_count));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.strings.checkin.pulse_type));
    await tester.pumpAndSettle();
    expect(find.byType(NumPad), findsOneWidget);
  });
}
