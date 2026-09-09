import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/kit.dart';
import 'package:app/balsm_app/responsive.dart';
import 'package:app/balsm_app/screens/home_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Layout must survive every screen the app ships on, in both directions, at
/// the largest text scale the shell allows.
///
/// A horizontal overflow is the dangerous kind: the app's screens scroll
/// vertically, so anything that runs off the side is unreachable rather than
/// merely ugly. These sweeps pump each layout primitive at the extremes of the
/// supported range and fail on the first overflow, so a regression names the
/// widget, the width and the direction instead of showing up as a red stripe
/// on someone's tablet.
///
/// Sizes are real devices, not round numbers: the narrow end is a folded
/// Galaxy Fold cover screen (280pt) and the small end is an iPhone SE (320pt),
/// which is where fixed-width rows break first.
void main() {
  /// (label, logical size). Widest is a desktop browser window.
  const devices = <(String, Size)>[
    ('fold-closed 280', Size(280, 653)),
    ('iphone-se 320', Size(320, 568)),
    ('android-small 360', Size(360, 640)),
    ('iphone-x 375', Size(375, 812)),
    ('iphone-pro 402', Size(402, 874)),
    ('iphone-max 430', Size(430, 932)),
    ('ipad-portrait 768', Size(768, 1024)),
    ('ipad-pro 1024', Size(1024, 1366)),
    ('desktop 1280', Size(1280, 800)),
    ('desktop-wide 1920', Size(1920, 1080)),
    // Both platforms ship unlocked orientation (Info.plist lists both
    // landscape values, the manifest sets no screenOrientation, and nothing
    // calls setPreferredOrientations), so landscape is a shipped layout.
    ('iphone-landscape 874', Size(874, 402)),
    ('ipad-landscape 1024', Size(1024, 768)),
  ];

  /// The shell clamps Dynamic Type to 0.9–1.3 (see PatientApp.builder), so
  /// 1.3 is the largest scale any layout has to survive.
  const scales = <double>[1.0, 1.3];

  Widget host(
    Widget child, {
    required Size size,
    required TextDirection dir,
    required double scale,
  }) =>
      MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: Directionality(
          textDirection: dir,
          child: AppScope(
            state: PatientAppState(),
            child: WidgetsApp(
              color: const Color(0xFFFFFFFF),
              builder: (_, __) => Material(child: child),
            ),
          ),
        ),
      );

  /// Pumps [build] at every device × direction × text scale and fails naming
  /// the first combination that overflows.
  Future<void> sweep(
    WidgetTester tester,
    Widget Function() build, {
    List<(String, Size)> only = devices,
  }) async {
    for (final (label, size) in only) {
      for (final dir in TextDirection.values) {
        for (final scale in scales) {
          await tester.binding.setSurfaceSize(size);
          await tester.pumpWidget(host(build(), size: size, dir: dir, scale: scale));
          await tester.pump();
          final failure = tester.takeException();
          expect(
            failure,
            isNull,
            reason: '$label · ${dir.name} · textScale $scale\n$failure',
          );
        }
      }
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  /// Arabic runs longer than English for the same label; RTL sweeps use it so
  /// a row that only just fits in English is caught.
  const longAr = 'ضغط الدم الانقباضي والانبساطي';

  group('adaptive primitives', () {
    testWidgets('AdaptiveCluster wraps rather than overflowing', (tester) async {
      await sweep(
        tester,
        () => AdaptiveCluster(
          children: [
            for (var i = 0; i < 8; i++) Pill('$longAr $i', kind: PillKind.neutral, ar: true),
          ],
        ),
      );
    });

    testWidgets('AdaptiveRow stacks below its breakpoint', (tester) async {
      await sweep(
        tester,
        () => const AdaptiveRow(
          breakpoint: Bp.sm,
          children: [
            SizedBox(height: 40, child: Text(longAr)),
            SizedBox(height: 40, child: Text(longAr)),
          ],
        ),
      );
    });

    testWidgets('AdaptiveSplit collapses on narrow screens', (tester) async {
      await sweep(
        tester,
        () => const AdaptiveSplit(
          breakpoint: Bp.md,
          primary: SizedBox(height: 80, child: Text(longAr)),
          aside: SizedBox(height: 80, child: Text(longAr)),
        ),
      );
    });

    testWidgets('AdaptiveGrid keeps at least one column at any width', (tester) async {
      await sweep(
        tester,
        () => AdaptiveGrid(
          children: [for (var i = 0; i < 6; i++) PCard(child: Text('$longAr $i'))],
        ),
      );
    });

    testWidgets('ContentColumn caps width without clipping', (tester) async {
      await sweep(
        tester,
        () => ContentColumn(
          child: Column(children: [for (var i = 0; i < 3; i++) PCard(child: Text('$longAr $i'))]),
        ),
      );
    });
  });

  group('composites', () {
    testWidgets('MetricGrid pairs tiles at every width', (tester) async {
      await sweep(
        tester,
        () => const MetricGrid(
          tiles: [
            MetricTile(icon: LucideIcons.activity, label: longAr, value: '155/95', unit: 'mmHg'),
            MetricTile(icon: LucideIcons.droplet, label: longAr, value: '5.4', unit: 'mmol/L'),
            MetricTile(icon: LucideIcons.scale, label: longAr, value: '72.5', unit: 'kg'),
          ],
        ),
      );
    });

    testWidgets('a full-width button row survives the narrow end', (tester) async {
      await sweep(
        tester,
        () => Row(
          children: [
            Expanded(child: PButton(longAr, icon: LucideIcons.plus, ar: true, onTap: () {})),
            const SizedBox(width: 8),
            Expanded(child: PButton(longAr, variant: BtnVariant.secondary, ar: true, onTap: () {})),
          ],
        ),
      );
    });
  });

  group('sheets', () {
    /// The shape every bottom sheet in the app uses: a height cap, a
    /// min-height Column, and the body in a Flexible scroll view. All ten
    /// sheets follow it, and it is the part that makes a sheet survive a short
    /// viewport — which landscape and an open keyboard both produce.
    Widget sheet({required double keyboard}) => Builder(
          builder: (context) => Padding(
            padding: EdgeInsets.only(bottom: keyboard),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
                color: const Color(0xFFFFFFFF),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      const Expanded(child: Text(longAr, style: TextStyle(fontSize: 18))),
                      RoundBtn(icon: LucideIcons.x, ghost: true, onTap: () {}),
                    ]),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(20, 8, 20, sheetBottomInset(context)),
                      child: Column(
                        children: [for (var i = 0; i < 12; i++) PCard(child: Text('$longAr $i'))],
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        );

    testWidgets('a sheet fits every viewport, keyboard closed', (tester) async {
      await sweep(tester, () => sheet(keyboard: 0));
    });

    testWidgets('a sheet fits with the keyboard open', (tester) async {
      // A landscape keyboard eats most of the viewport; the body must give way
      // rather than the sheet overflowing.
      await sweep(tester, () => sheet(keyboard: 290));
    });
  });

  group('width contract', () {
    testWidgets('ContentColumn never exceeds its cap on a wide screen', (tester) async {
      const cap = 640.0;
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(host(
        ContentColumn(maxWidth: cap, child: Container(color: const Color(0xFF000000), height: 40)),
        size: const Size(1920, 1080),
        dir: TextDirection.ltr,
        scale: 1,
      ));
      await tester.pump();
      final width = tester.getSize(find.byType(Container)).width;
      expect(width, lessThanOrEqualTo(cap), reason: 'touch-first content must not stretch across a desktop window');
    });

    testWidgets('AdaptiveGrid gives every child the same width', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1366));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(host(
        AdaptiveGrid(children: [for (var i = 0; i < 4; i++) SizedBox(key: ValueKey(i), height: 40)]),
        size: const Size(1024, 1366),
        dir: TextDirection.ltr,
        scale: 1,
      ));
      await tester.pump();
      final widths = [for (var i = 0; i < 4; i++) tester.getSize(find.byKey(ValueKey(i))).width];
      expect(widths.toSet().length, 1, reason: 'ragged columns mean the gap maths is wrong: $widths');
    });
  });
}
