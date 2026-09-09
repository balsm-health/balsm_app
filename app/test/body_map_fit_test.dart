import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/widgets/body_map.dart';
import 'package:core/core.dart' show Gender;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The anatomy plate must never be clipped.
///
/// `.bm-host svg` caps BOTH axes — `height: min(320px, 40vh)` and
/// `max-width: 100%`. Pinning the height with a SizedBox forced the width that
/// the 200x384 viewBox implies; anywhere the column was narrower than that the
/// plate overflowed sideways, and a horizontal overflow is exactly the kind a
/// vertically-scrolling sheet can never reveal.
void main() {
  const ratio = 200 / 384;

  Widget host({required Size surface, required double width}) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: surface),
          child: AppScope(
            state: PatientAppState(),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: width,
                    child: SingleChildScrollView(
                      child: BodyMap(selected: const {}, onToggle: (_) {}, gender: Gender.female),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  /// The rendered plate, i.e. the box the artwork is painted into.
  Size plate(WidgetTester tester) => tester.getSize(find.byType(SvgPicture));

  testWidgets('plate keeps the artwork aspect ratio', (tester) async {
    await tester.pumpWidget(host(surface: const Size(402, 874), width: 362));
    await tester.pump();
    final s = plate(tester);
    expect(s.width / s.height, closeTo(ratio, 0.01));
  });

  testWidgets('height is capped at the design maximum on a tall screen', (tester) async {
    await tester.pumpWidget(host(surface: const Size(402, 874), width: 362));
    await tester.pump();
    // 40vh of 874 is 349.6, so the 320 cap wins.
    expect(plate(tester).height, closeTo(320, 0.5));
  });

  testWidgets('a narrow column scales the plate down instead of clipping it', (tester) async {
    // 120pt of usable width cannot hold the 167pt the 320pt height implies.
    const width = 120.0;
    await tester.pumpWidget(host(surface: const Size(402, 874), width: width));
    await tester.pump();
    final s = plate(tester);
    expect(s.width, lessThanOrEqualTo(width), reason: 'overflowing sideways is unrecoverable in a vertical scroll');
    expect(s.width / s.height, closeTo(ratio, 0.01), reason: 'scaled down, not squashed');
  });

  testWidgets('short screens fall back to the 220pt floor', (tester) async {
    // 40vh of 500 is 200, below the floor.
    await tester.pumpWidget(host(surface: const Size(402, 500), width: 362));
    await tester.pump();
    expect(plate(tester).height, closeTo(220, 0.5));
  });

  testWidgets('no overflow is reported at any of these widths', (tester) async {
    for (final w in [120.0, 200.0, 362.0, 520.0]) {
      await tester.pumpWidget(host(surface: const Size(402, 874), width: w));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'width $w overflowed');
    }
  });
}
