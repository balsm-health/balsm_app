import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/screens/checkin_shared.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// `MoodCell` — the five mood faces sit in a `Row` of `Expanded` cells
/// (metric_log.dart `_MoodTemplate`, reached from the check-in flow), so each
/// cell is a square whose side is the pane width minus the gutters, divided by
/// five. On a 360dp phone that is ~56dp, while the cell's own content — a 34dp
/// face, an 8dp gap and a label line — needs more. The cell must absorb that
/// rather than overflow.
///
/// Arabic is the hard case and the one that was reported: the Arabic face has
/// taller line metrics and the labels are longer, which overflowed by 76px on
/// a real handset. The shell also clamps the text scaler to 1.3 (shell.dart),
/// so that bound is covered too.
void main() {
  Future<Object?> overflowAt(WidgetTester tester, {required double textScale, required bool arabic}) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final state = PatientAppState();
    if (arabic) state.lang = LanguageCode.ar;
    await tester.pumpWidget(MaterialApp(
      locale: Locale(state.lang.value),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Directionality(
          textDirection: state.dir,
          child: Scaffold(
            body: Padding(
              // The screen gutters the template sits inside.
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: List.generate(
                  5,
                  (i) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: i < 4 ? 10 : 0),
                      child: MoodCell(lv: i + 1, selected: i == 2, s: state, onTap: () {}),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ));
    return tester.takeException();
  }

  testWidgets('english, default text scale', (tester) async {
    expect(await overflowAt(tester, textScale: 1.0, arabic: false), isNull);
  });

  testWidgets('english, shell max text scale (1.3)', (tester) async {
    expect(await overflowAt(tester, textScale: 1.3, arabic: false), isNull);
  });

  testWidgets('arabic, default text scale', (tester) async {
    expect(await overflowAt(tester, textScale: 1.0, arabic: true), isNull);
  });

  testWidgets('arabic, shell max text scale (1.3)', (tester) async {
    expect(await overflowAt(tester, textScale: 1.3, arabic: true), isNull);
  });
}
