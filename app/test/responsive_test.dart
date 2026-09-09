import 'package:app/balsm_app/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Coverage for `responsive.dart` — the shared adaptive layer every screen in
/// the app builds on (ContentColumn width caps, AdaptiveRow/Split/Grid
/// breakpoint swaps). Verifies the actual rendered layout at phone / tablet /
/// desktop widths, not just that the widgets compile.
void main() {
  group('ContentColumn', () {
    Future<double> capturedWidthAt(WidgetTester tester, Size surface) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      tester.view.physicalSize = surface;
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(const MaterialApp(
        home: ContentColumn(maxWidth: 720, child: SizedBox(key: Key('c'), width: double.infinity, height: 40)),
      ));
      return tester.getSize(find.byKey(const Key('c'))).width;
    }

    testWidgets('does not clip narrow (phone) content', (tester) async {
      final w = await capturedWidthAt(tester, const Size(375, 800));
      expect(w, closeTo(375, 0.5), reason: 'phone width should pass through uncapped');
    });

    testWidgets('caps width on a wide (desktop) surface', (tester) async {
      final w = await capturedWidthAt(tester, const Size(1440, 900));
      expect(w, closeTo(720, 0.5), reason: 'desktop width must be capped, never edge-to-edge');
    });
  });

  group('AdaptiveRow', () {
    Widget harness(double width) => MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: width,
              child: const AdaptiveRow(
                breakpoint: Bp.sm,
                children: [
                  SizedBox(key: Key('a'), height: 10),
                  SizedBox(key: Key('b'), height: 10),
                ],
              ),
            ),
          ),
        );

    testWidgets('stacks vertically below the sm breakpoint', (tester) async {
      await tester.pumpWidget(harness(320)); // < Bp.sm (480)
      final aTop = tester.getTopLeft(find.byKey(const Key('a'))).dy;
      final bTop = tester.getTopLeft(find.byKey(const Key('b'))).dy;
      expect(bTop, greaterThan(aTop), reason: 'narrow container: b must sit below a (Column)');
    });

    testWidgets('lays out as a row at/above the sm breakpoint', (tester) async {
      await tester.pumpWidget(harness(600)); // >= Bp.sm (480)
      final aTop = tester.getTopLeft(find.byKey(const Key('a'))).dy;
      final bTop = tester.getTopLeft(find.byKey(const Key('b'))).dy;
      final aLeft = tester.getTopLeft(find.byKey(const Key('a'))).dx;
      final bLeft = tester.getTopLeft(find.byKey(const Key('b'))).dx;
      expect(aTop, bTop, reason: 'wide container: a and b share a row');
      expect(bLeft, greaterThan(aLeft));
    });
  });

  group('AdaptiveSplit', () {
    Widget harness(double width) => MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: width,
              child: const AdaptiveSplit(
                breakpoint: Bp.md,
                primary: SizedBox(key: Key('primary'), height: 20),
                aside: SizedBox(key: Key('aside'), height: 20),
              ),
            ),
          ),
        );

    testWidgets('stacks primary above aside below the md breakpoint (phone)', (tester) async {
      await tester.pumpWidget(harness(400)); // < Bp.md (768)
      final primaryTop = tester.getTopLeft(find.byKey(const Key('primary'))).dy;
      final asideTop = tester.getTopLeft(find.byKey(const Key('aside'))).dy;
      expect(asideTop, greaterThan(primaryTop));
    });

    testWidgets('becomes a two-pane row at/above the md breakpoint (tablet)', (tester) async {
      await tester.pumpWidget(harness(900)); // >= Bp.md (768)
      final primaryTop = tester.getTopLeft(find.byKey(const Key('primary'))).dy;
      final asideTop = tester.getTopLeft(find.byKey(const Key('aside'))).dy;
      final asideLeft = tester.getTopLeft(find.byKey(const Key('aside'))).dx;
      final primaryLeft = tester.getTopLeft(find.byKey(const Key('primary'))).dx;
      expect(primaryTop, asideTop);
      expect(primaryLeft, greaterThan(asideLeft), reason: 'SplitMode.start: aside leads, primary trails');
    });
  });

  group('AdaptiveGrid', () {
    Future<int> columnCountAt(WidgetTester tester, double width) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            child: AdaptiveGrid(
              colMin: 150,
              children: List.generate(6, (i) => SizedBox(key: Key('t$i'), height: 40)),
            ),
          ),
        ),
      ));
      final firstTop = tester.getTopLeft(find.byKey(const Key('t0'))).dy;
      var cols = 0;
      for (var i = 0; i < 6; i++) {
        if (tester.getTopLeft(find.byKey(Key('t$i'))).dy == firstTop) cols++;
      }
      return cols;
    }

    testWidgets('one column on a narrow phone', (tester) async {
      expect(await columnCountAt(tester, 300), 1, reason: 'phone: a single 150-min column fits');
    });

    testWidgets('several columns on a wide (tablet-width) container', (tester) async {
      expect(await columnCountAt(tester, 780), greaterThanOrEqualTo(4), reason: 'wide container: several columns fit');
    });
  });
}
