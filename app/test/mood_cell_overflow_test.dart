import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/screens/checkin_shared.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// The mood row of the check-in is five square cells sharing one screen width,
/// and each cell has to hold a 34pt face, an 8pt gap and a line of label. On a
/// narrow phone the square is about 56pt, so the column asks for more height
/// than the cell has and the row overflows at the bottom — worse in Arabic,
/// whose labels are longer, and worse again at the 1.3 text scale the shell
/// allows.
///
/// These pump the real row, not the cell on its own, because the width each
/// cell gets — and therefore the height the AspectRatio gives it — only exists
/// once the five are laid out together.
void main() {
  /// Narrowest phone the app ships on, where the squares are smallest.
  const phone = Size(360, 640);

  /// PatientApp.builder clamps Dynamic Type to 0.9–1.3.
  const scales = <double>[1.0, 1.3];

  Widget host({required bool ar, required double scale}) {
    final state = PatientAppState();
    // Assigned rather than setLang(), which also writes prefs.
    if (ar) state.lang = LanguageCode.ar;
    return MediaQuery(
      data: const MediaQueryData(size: phone).copyWith(textScaler: TextScaler.linear(scale)),
      child: Directionality(
        textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
        child: AppScope(
          state: state,
          child: WidgetsApp(
            color: const Color(0xFFFFFFFF),
            builder: (_, __) => Material(
              child: Padding(
                // The 20pt page gutter the check-in templates apply.
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
      ),
    );
  }

  for (final ar in [false, true]) {
    for (final scale in scales) {
      final lang = ar ? 'arabic' : 'english';
      testWidgets('mood row fits on a 360pt phone — $lang, text scale $scale', (tester) async {
        await tester.binding.setSurfaceSize(phone);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(host(ar: ar, scale: scale));
        await tester.pump();

        final failure = tester.takeException();
        expect(failure, isNull, reason: '$lang · text scale $scale\n$failure');
      });
    }
  }
}
