import 'package:app/balsm_app/screens/metric_log.dart';
import 'package:app/balsm_app/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a 300pt-wide slider and returns the values it reports.
Future<List<double>> _tapAt(WidgetTester tester, double dx, {TextDirection dir = TextDirection.ltr}) async {
  final reported = <double>[];
  await tester.pumpWidget(MaterialApp(
    home: Directionality(
      textDirection: dir,
      child: Center(
        child: SizedBox(
          width: 300,
          child: PainSlider(value: 0, knobColor: T.danger, onChanged: reported.add),
        ),
      ),
    ),
  ));
  // Padding is fromLTRB(4, 18, 4, 6) and the track is 56 tall, so its centre
  // is 18 + 28 below the widget top. The tick row sits below that — tapping
  // the widget's own centre would miss the track entirely.
  final top = tester.getTopLeft(find.byType(PainSlider));
  await tester.tapAt(Offset(top.dx + 4 + dx, top.dy + 18 + 28));
  await tester.pump();
  return reported;
}

void main() {
  testWidgets('reports 0 at the start of the rail', (tester) async {
    expect((await _tapAt(tester, 0)).single, 0);
  });

  testWidgets('reports 10 at the end of the rail', (tester) async {
    expect((await _tapAt(tester, 291)).single, 10);
  });

  testWidgets('reports a mid value near the middle', (tester) async {
    // Knob centre travels over (292 - 36) = 256pt; midpoint is 18 + 128.
    final v = (await _tapAt(tester, 18 + 128)).single;
    expect(v, 5);
  });

  testWidgets('snaps to whole numbers', (tester) async {
    for (final dx in [40.0, 90.0, 150.0, 210.0, 270.0]) {
      final v = (await _tapAt(tester, dx)).single;
      expect(v, v.roundToDouble(), reason: 'value $v is not a whole step');
      expect(v, inInclusiveRange(0, 10));
    }
  });

  testWidgets('mirrors in RTL — the start of the rail is 10', (tester) async {
    expect((await _tapAt(tester, 0, dir: TextDirection.rtl)).single, 10);
    expect((await _tapAt(tester, 291, dir: TextDirection.rtl)).single, 0);
  });
}
