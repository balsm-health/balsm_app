import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/screens/checkin_shared.dart';
import 'package:app/balsm_app/screens/metric_log.dart';
import 'package:core/core.dart' show LanguageCode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:self_report/self_report.dart';

/// The five mood faces on a 360dp phone (Galaxy A17): each square is ~51dp,
/// smaller than the face and label, which overflowed. They must fit, and all
/// five must be the same size.
void main() {
  Future<void> pump(WidgetTester tester, {bool arabic = false, double textScale = 1}) async {
    final s = PatientAppState();
    if (arabic) s.setLang(LanguageCode.ar);
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      child: AppScope(
        state: s,
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: const Size(360, 800), textScaler: TextScaler.linear(textScale)),
            child: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: MetricLog(metric: CheckInMetric.mood, s: s, host: MetricLogHost.embedded),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  for (final arabic in [false, true]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('fits at 360dp (${arabic ? 'ar' : 'en'}, text ×$scale)', (tester) async {
        await pump(tester, arabic: arabic, textScale: scale);
        expect(tester.takeException(), isNull);
        final sizes = find.byType(MoodCell).evaluate().map((e) => tester.getSize(find.byWidget(e.widget))).toSet();
        expect(sizes, hasLength(1), reason: 'every mood cell is the same size');
      });
    }
  }
}
