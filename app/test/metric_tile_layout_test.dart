import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/kit.dart';
import 'package:app/balsm_app/screens/home_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// `.metric-grid` fidelity (home screen "latest readings").
///
/// Two device-only defects this guards against, both invisible in a plain
/// `MaterialApp` test host and both reproduced here with a notched phone's
/// `MediaQuery.padding`:
///
///  1. `BoxScrollView` silently applies MediaQuery's *vertical* padding when
///     its own `padding` is null — a nested grid then inherits the 62pt notch
///     inset as dead space above the first tile.
///  2. The reading is the hero of the tile and must stay fully legible; a wide
///     Arabic unit plus a 3-digit systolic used to ellipsize it ("155/9…").
void main() {
  const phone = Size(402, 1400);
  const notch = MediaQueryData(padding: EdgeInsets.only(top: 62, bottom: 34));

  /// Column width the home grid gives each tile: 402 − 40 page padding − 12 gap.
  const colWidth = (402 - 40 - 12) / 2;

  Widget host(Widget child, {TextDirection dir = TextDirection.ltr}) => MaterialApp(
        home: MediaQuery(
          data: notch,
          child: AppScope(
            state: PatientAppState(),
            child: Directionality(
              textDirection: dir,
              child: Scaffold(body: child),
            ),
          ),
        ),
      );

  const tile = MetricTile(
    icon: LucideIcons.activity,
    label: 'Blood pressure',
    value: '120/80',
    unit: 'mmHg',
    foot: 'Slightly high',
    footTone: true,
  );

  /// The real home-screen section: `RowHead` + the shared [MetricGrid], with
  /// the same 20pt page gutters `_LatestMetrics` applies.
  Widget metricGrid(List<Widget> tiles) => ListView(
        padding: EdgeInsets.zero,
        children: [
          const RowHead('Latest'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: MetricGrid(tiles: tiles),
          ),
        ],
      );

  testWidgets('nested grid does not inherit the notch inset as top padding', (tester) async {
    await tester.binding.setSurfaceSize(phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(host(metricGrid(const [tile])));

    final headBottom = tester.getRect(find.byType(RowHead)).bottom;
    final tileTop = tester.getRect(find.byType(MetricTile)).top;
    expect(tileTop - headBottom, lessThan(4),
        reason: 'nested GridView must pass padding: EdgeInsets.zero, else it '
            'inherits MediaQuery.padding.top (62pt) as dead space');
  });

  testWidgets('grid lays out in rows of two and stays inside the page gutters', (tester) async {
    await tester.binding.setSurfaceSize(phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(host(metricGrid(const [tile, tile, tile])));

    final rects = tester.widgetList(find.byType(MetricTile)).toList().asMap().keys.map((i) {
      return tester.getRect(find.byType(MetricTile).at(i));
    }).toList();

    expect(rects[0].top, rects[1].top, reason: 'first two tiles share a row');
    expect(rects[2].top, greaterThan(rects[0].top), reason: 'third tile wraps to the next row');
    expect(rects[0].width, closeTo(colWidth, 0.5));
    for (final r in rects) {
      expect(r.left, greaterThanOrEqualTo(20 - 0.5));
      expect(r.right, lessThanOrEqualTo(402 - 20 + 0.5));
    }
  });

  testWidgets('a long reading with a wide Arabic unit is scaled, not ellipsized', (tester) async {
    await tester.binding.setSurfaceSize(phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(host(
      metricGrid(const [
        MetricTile(
          icon: LucideIcons.activity,
          label: 'ضغط الدم',
          value: '155/95',
          unit: 'ملم زئبق',
          foot: 'أعلى قليلاً',
          footTone: true,
        ),
      ]),
      dir: TextDirection.rtl,
    ));

    // The value must never be ellipsized — it is scaled to fit instead.
    final valueText = tester.widget<Text>(find.text('155/95'));
    expect(valueText.overflow, isNot(TextOverflow.ellipsis),
        reason: 'the reading must scale down rather than truncate');
    expect(find.byType(FittedBox), findsWidgets);

    // And it must physically fit inside the tile's 16pt content padding.
    final tileRect = tester.getRect(find.byType(MetricTile));
    final valueRect = tester.getRect(find.text('155/95'));
    expect(valueRect.left, greaterThanOrEqualTo(tileRect.left + 16 - 0.5));
    expect(valueRect.right, lessThanOrEqualTo(tileRect.right - 16 + 0.5));
  });

  testWidgets('no overflow at the smallest supported width and largest text scale', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        // shell.dart clamps Dynamic Type to at most 1.3.
        data: notch.copyWith(textScaler: const TextScaler.linear(1.3)),
        child: AppScope(
          state: PatientAppState(),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: metricGrid(const [tile, tile])),
          ),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
  });
}
