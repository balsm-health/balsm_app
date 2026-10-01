import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/widgets/body_map.dart';
import 'package:core/core.dart' show Gender;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:self_report/self_report.dart';

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

  /// The asset path the plate is currently painting.
  String plateAsset(WidgetTester tester) =>
      (tester.widget<SvgPicture>(find.byType(SvgPicture)).bytesLoader as SvgAssetLoader).assetName;

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
    // Below this, the layer row's own fixed-size Front/Back chips (design:
    // "chips don't wrap internally") no longer fit regardless of the plate —
    // out of scope for this test, which is only about the plate's own
    // AspectRatio/ConstrainedBox math, so the unrelated overflow is consumed.
    tester.takeException();
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
    // 120pt is below the layer row's own fixed-chip floor (see the scaled-down
    // test above) — out of scope for the design's "no overflow at 320px"
    // guarantee, which the layer-dropdown group below exercises directly.
    for (final w in [200.0, 362.0, 520.0]) {
      await tester.pumpWidget(host(surface: const Size(402, 874), width: w));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'width $w overflowed');
    }
  });

  group('layer dropdown and region chips', () {
    // A few Skin regions to stand in for marked sites — any BodyRegion works,
    // skin is the default layer so these render without switching tissue.
    const headSite = PainSite(Skin.head);
    const neckSite = PainSite(Skin.neck);
    const jawSite = PainSite(Skin.jaw);

    Widget harness({
      Set<PainSite> selected = const {},
      ValueChanged<PainSite>? onToggle,
      TextDirection dir = TextDirection.ltr,
      double textScale = 1.0,
      double width = 362,
    }) =>
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(402, 874)).copyWith(textScaler: TextScaler.linear(textScale)),
            child: AppScope(
              state: PatientAppState(),
              child: Directionality(
                textDirection: dir,
                child: Scaffold(
                  body: Center(
                    child: SizedBox(
                      width: width,
                      child: SingleChildScrollView(
                        child: BodyMap(selected: selected, onToggle: onToggle ?? (_) {}, gender: Gender.female),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

    testWidgets('selecting a layer in the dropdown switches the plate asset', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pump();
      expect(plateAsset(tester), 'assets/body/female_front.svg');

      await tester.tap(find.byType(DropdownButton<BodyTissue>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Muscle').last);
      await tester.pumpAndSettle();

      expect(plateAsset(tester), 'assets/body/muscles_front.svg');
    });

    testWidgets('dropdown has semantics label "Layer"', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(harness());
      await tester.pump();
      expect(find.bySemanticsLabel('Layer'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('nothing selected shows the tap caption, not chips', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pump();
      expect(find.text('Tap to mark location'), findsOneWidget);
      expect(find.byIcon(LucideIcons.x), findsNothing);
    });

    testWidgets('the remove button on a selected chip calls onToggle with that site', (tester) async {
      final calls = <PainSite>[];
      await tester.pumpWidget(harness(selected: {headSite}, onToggle: calls.add));
      await tester.pump();

      expect(find.byIcon(LucideIcons.x), findsOneWidget);
      await tester.tap(find.byIcon(LucideIcons.x));
      await tester.pump();

      expect(calls, [headSite]);
    });

    testWidgets('Clear all toggles every selected site', (tester) async {
      final calls = <PainSite>[];
      await tester.pumpWidget(harness(selected: {headSite, neckSite, jawSite}, onToggle: calls.add));
      await tester.pump();

      expect(find.text('Clear all'), findsOneWidget);
      await tester.tap(find.text('Clear all'));
      await tester.pump();

      expect(calls.toSet(), {headSite, neckSite, jawSite});
    });

    testWidgets('no Clear all with a single selected site', (tester) async {
      await tester.pumpWidget(harness(selected: {headSite}));
      await tester.pump();
      expect(find.text('Clear all'), findsNothing);
    });

    testWidgets('no overflow at 320px width, LTR, with chips showing', (tester) async {
      await tester.pumpWidget(harness(selected: {headSite, neckSite, jawSite}, width: 320));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('no overflow at 1.3x text scale, LTR', (tester) async {
      await tester.pumpWidget(harness(selected: {headSite, neckSite, jawSite}, width: 320, textScale: 1.3));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('no overflow at 1.3x text scale, Arabic RTL', (tester) async {
      await tester.pumpWidget(
        harness(selected: {headSite, neckSite, jawSite}, width: 320, textScale: 1.3, dir: TextDirection.rtl),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
