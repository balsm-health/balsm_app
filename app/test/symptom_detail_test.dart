import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/screens/metric_log.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:core/core.dart' show LanguageCode;
import 'package:self_report/self_report.dart';

/// `quicklog.jsx` `QuickSymptomDetail` — the urine card (colour · quantity ·
/// blood) and the stool card (blood).
///
/// These are patient observations, recorded verbatim. Nothing here interprets
/// them, so the tests assert capture, not meaning.
void main() {
  Future<(PatientAppState, List<MetricLogCapture>)> pumpSymptom(
    WidgetTester tester,
    SymptomId symptom, {
    Size? window,
    bool arabic = false,
  }) async {
    final state = PatientAppState();
    if (arabic) state.setLang(LanguageCode.ar);
    if (window != null) {
      tester.view.physicalSize = window;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }
    final captures = <MetricLogCapture>[];
    await tester.pumpWidget(ProviderScope(
      child: AppScope(
        state: state,
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MetricLog(
                metric: CheckInMetric.symptoms,
                s: state,
                host: MetricLogHost.standalone,
                focusedSymptom: symptom,
                onChanged: (c, {required bool valid}) => captures.add(c),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return (state, captures);
  }

  testWidgets('a plain symptom gets no detail card', (tester) async {
    final (s, _) = await pumpSymptom(tester, SymptomId.headache);
    expect(find.text(s.strings.checkin.sd_blood), findsNothing);
    expect(find.text(s.strings.checkin.sd_color), findsNothing);
  });

  testWidgets('urine asks for colour, quantity and blood', (tester) async {
    final (s, _) = await pumpSymptom(tester, SymptomId.urine);
    expect(find.text(s.strings.checkin.sd_color), findsOne);
    expect(find.text(s.strings.checkin.sd_quantity), findsOne);
    expect(find.text(s.strings.checkin.sd_blood), findsOne);
    // One swatch per catalog colour.
    expect(find.text(s.strings.checkin.sd_u_pale), findsOne);
    expect(find.text(s.strings.checkin.sd_u_brown), findsOne);
  });

  testWidgets('stool asks only about blood', (tester) async {
    final (s, _) = await pumpSymptom(tester, SymptomId.stool);
    expect(find.text(s.strings.checkin.sd_blood), findsOne);
    expect(find.text(s.strings.checkin.sd_color), findsNothing);
    expect(find.text(s.strings.checkin.sd_quantity), findsNothing);
  });

  testWidgets('the quantity steps by 50 and never goes below zero', (tester) async {
    final (_, captures) = await pumpSymptom(tester, SymptomId.urine);
    expect(find.text('0'), findsOne);

    await tester.tap(find.byIcon(LucideIcons.plus));
    await tester.pumpAndSettle();
    expect(find.text('50'), findsOne);

    await tester.tap(find.byIcon(LucideIcons.plus));
    await tester.pumpAndSettle();
    expect(find.text('100'), findsOne);

    // Each tap must land on a rebuilt tree: the handlers close over the
    // detail of the frame they were built in.
    await tester.tap(find.byIcon(LucideIcons.minus));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(LucideIcons.minus));
    await tester.pumpAndSettle();
    expect(find.text('0'), findsOne);
    expect(captures.last.symptomDetails[SymptomId.urine]?.urineMl, 0);
  });

  testWidgets('picking a colour records it; picking it again clears it', (tester) async {
    final (s, captures) = await pumpSymptom(tester, SymptomId.urine);

    await tester.tap(find.text(s.strings.checkin.sd_u_dark));
    await tester.pumpAndSettle();
    expect(captures.last.symptomDetails[SymptomId.urine]?.urineColor, UrineColor.dark);

    await tester.tap(find.text(s.strings.checkin.sd_u_dark));
    await tester.pumpAndSettle();
    expect(captures.last.symptomDetails[SymptomId.urine]?.urineColor, isNull);
  });

  testWidgets('blood toggles, and reaches the capture', (tester) async {
    final (s, captures) = await pumpSymptom(tester, SymptomId.stool);
    await tester.tap(find.text(s.strings.checkin.sd_blood));
    await tester.pumpAndSettle();
    expect(captures.last.symptomDetails[SymptomId.stool]?.blood, isTrue);
  });

  testWidgets('an untouched card stores no observation at all', (tester) async {
    final (_, captures) = await pumpSymptom(tester, SymptomId.urine);
    expect(captures.last.symptomDetails, isEmpty, reason: 'silence is not a reading');
  });

  testWidgets('what was observed is appended to the saved summary', (tester) async {
    final (s, captures) = await pumpSymptom(tester, SymptomId.urine);
    await tester.tap(find.text(s.strings.checkin.sd_u_red));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(LucideIcons.plus));
    await tester.pumpAndSettle();

    final summary = captures.last.summary;
    expect(summary, contains(s.strings.checkin.sym_urine));
    expect(summary, contains(s.strings.checkin.sd_u_red));
    expect(summary, contains('50 ${s.strings.checkin.sd_ml}'));
  });

  group('layout', () {
    // The narrowest supported phone; five swatches plus a stepper have to fit.
    const narrow = Size(360, 780);

    testWidgets('the urine card fits a narrow phone', (tester) async {
      await pumpSymptom(tester, SymptomId.urine, window: narrow);
      expect(tester.takeException(), isNull);
    });

    testWidgets('it fits in Arabic too, where the labels are longer', (tester) async {
      await pumpSymptom(tester, SymptomId.urine, window: narrow, arabic: true);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a four-digit volume does not overflow the stepper', (tester) async {
      await pumpSymptom(tester, SymptomId.urine, window: narrow);
      // 1500ml is a plausible day's output; the box must grow, not clip.
      for (var i = 0; i < 30; i++) {
        await tester.tap(find.byIcon(LucideIcons.plus));
        await tester.pumpAndSettle();
      }
      expect(find.text('1500'), findsOne);
      expect(tester.takeException(), isNull);
    });
  });
}
