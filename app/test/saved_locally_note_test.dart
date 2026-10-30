import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/screens/report_flow.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// The pill under the tick on the screen that closes a check-in.
///
/// It hugs its label — a pill the width of the screen would not read as one —
/// which is exactly why it overflowed: the label is a whole sentence
/// ("Saved locally. Will sync when you reconnect."), and a row that hugs an
/// unyielding child asks for the sentence's full single-line width however
/// little the screen has. On a 360pt phone the 24pt page padding and the
/// pill's own 14pt leave it about 261pt.
///
/// The screen around it takes a half-finished check-in to reach, so these pump
/// the pill in the same place the summary puts it: the 24pt-padded column
/// inside a 480pt `ContentColumn`.
void main() {
  const devices = <(String, Size)>[
    ('fold-closed 280', Size(280, 653)),
    ('iphone-se 320', Size(320, 568)),
    ('android-small 360', Size(360, 640)),
    ('iphone-pro 402', Size(402, 874)),
  ];

  /// PatientApp.builder clamps Dynamic Type to 0.9–1.3.
  const scales = <double>[1.0, 1.3];

  Widget host({required Size size, required bool ar, required double scale}) {
    final state = PatientAppState();
    // Assigned rather than setLang(), which also writes prefs.
    if (ar) state.lang = LanguageCode.ar;
    return MediaQuery(
      data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
      child: Directionality(
        textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
        child: AppScope(
          state: state,
          child: WidgetsApp(
            color: const Color(0xFFFFFFFF),
            builder: (_, __) => Material(
              child: Padding(
                // The gutters `_Summary` puts around the pill.
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(children: [SavedLocallyNote(s: state)]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  for (final (label, size) in devices) {
    for (final ar in [false, true]) {
      for (final scale in scales) {
        final lang = ar ? 'arabic' : 'english';
        testWidgets('the pill stays on screen — $label, $lang, text scale $scale', (tester) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          await tester.pumpWidget(host(size: size, ar: ar, scale: scale));
          await tester.pump();

          final failure = tester.takeException();
          expect(failure, isNull, reason: '$label · $lang · text scale $scale\n$failure');
        });
      }
    }
  }

  testWidgets('it still hugs its label where there is room to spare', (tester) async {
    const wide = Size(1024, 768);
    await tester.binding.setSurfaceSize(wide);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(host(size: wide, ar: false, scale: 1.0));
    await tester.pump();

    // A pill that stretched the full column would be a different bug fixed by
    // the same `Flexible`, so pin the hug rather than only the overflow.
    expect(tester.getSize(find.byType(SavedLocallyNote)).width, lessThan(wide.width - 48));
  });
}
