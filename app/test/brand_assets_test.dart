import 'dart:io';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

/// The shipped brand mark.
///
/// `app/assets/brand/*.svg` are copies of `Balsm-Core/brand/*.svg` — the same
/// files the claude.ai/design project ships as `assets/icon.svg` — rewritten
/// by `tool/sync_brand_svg.py` into the dialect `flutter_svg` reads.
///
/// Both halves of that have gone wrong before: the app's copy sat on an older
/// mark (head `cy` 73.655, a viewBox that clipped the outer heads) for several
/// design revisions, and the SVG-2 features Core authors in are silently
/// dropped by the compiler rather than rejected. These assertions pin the
/// geometry and the dialect so the next drift fails here instead of shipping.
void main() {
  const brand = 'assets/brand';

  /// The mark's ink box, measured from its own geometry: five heads of r 58.65
  /// centred 312.92 from the ring centre at 72° steps put the extremes at
  /// x 18.27→730.73 and y 11.43→694.80, rounded outward to 0.01.
  const inkBox = 'viewBox="18.24 11.42 712.52 683.39"';

  String read(String path) {
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: '$path is missing');
    return file.readAsStringSync();
  }

  group('icon.svg', () {
    late final svg = read('$brand/icon.svg');

    test('frames the mark on its measured ink box', () {
      expect(svg, contains(inkBox));
    });

    test('carries the current head geometry', () {
      // The stale copy had cy 73.655, which is what moved the ink box.
      expect(svg, contains('cx="374.5" cy="70.08" r="58.65"'));
    });

    test('draws one ribbon and one head, five times each', () {
      expect(RegExp(r'<use href="#ribbon"').allMatches(svg), hasLength(5));
      expect(RegExp(r'<use href="#head"').allMatches(svg), hasLength(5));
    });
  });

  for (final name in const ['icon.svg', 'logo-vertical.svg']) {
    group(name, () {
      late final svg = read('$brand/$name');

      test('inlines the shared gradient axis', () {
        // `<linearGradient href="#axis">` compiles to stops with no geometry,
        // which paints every ribbon from its own box instead of one sweep.
        expect(
          RegExp(r'<linearGradient[^>]*\shref="#').allMatches(svg),
          isEmpty,
          reason: 'run tool/sync_brand_svg.py rather than copying Core by hand',
        );
        expect(RegExp(r'<linearGradient[^>]*gradientUnits="userSpaceOnUse"').allMatches(svg).length,
            greaterThanOrEqualTo(10));
      });

      test('drops the SVG-2 paint fallback', () {
        // `fill="url(#a) #02BBB5"` parses as one unmatched reference and the
        // fill is dropped, leaving the shape unpainted.
        expect(RegExp(r'fill="url\(#[^)]+\)\s+#').allMatches(svg), isEmpty);
      });

      testWidgets('parses through flutter_svg', (tester) async {
        // Compiles the SVG the same way the running app does; a malformed
        // file throws here instead of rendering blank on a device.
        final picture = await vg.loadPicture(SvgStringLoader(svg), null);
        addTearDown(picture.picture.dispose);
        expect(picture.size.width, greaterThan(0));
        expect(picture.size.height, greaterThan(0));
      });
    });
  }

  group('icon-mono-white.svg', () {
    late final svg = read('$brand/icon-mono-white.svg');

    test('keeps its padded square canvas, unlike the tight colour mark', () {
      // icon.svg is cropped to its ink box; the mono-white variant Core
      // generates is a padded 1024 square. `home.jsx` points .petal-wm at
      // this same variant inside a fixed 150px box, so the extra margin is
      // the design's framing, not a mistake — pinned so a future re-crop of
      // either file is a visible failure rather than a silently resized
      // watermark.
      expect(svg, contains('viewBox="0 0 1024 1024"'));
      expect(svg, isNot(contains(inkBox)));
    });

    test('paints white and nothing else', () {
      // A watermark on an accent fill. Any other ink here would mean Core
      // shipped the wrong variant, which is invisible until it renders.
      final fills = RegExp(r'fill="(?!none")([^"]+)"').allMatches(svg).map((m) => m.group(1)!).toSet();
      expect(fills.difference({'#fff', '#FFF', '#ffffff', '#FFFFFF', 'white'}), isEmpty,
          reason: 'unexpected ink in the mono-white mark: $fills');
    });

    testWidgets('resolves its <use href> through flutter_svg', (tester) async {
      // Core authors this with <defs> + <use href="#…">. The compiler drops
      // what it cannot resolve rather than failing, so a silent break here
      // ships a blank watermark — this renders it for real.
      final picture = await vg.loadPicture(SvgStringLoader(svg), null);
      addTearDown(picture.picture.dispose);
      expect(picture.size.width, greaterThan(0));
      expect(picture.size.height, greaterThan(0));
    });
  });
}
