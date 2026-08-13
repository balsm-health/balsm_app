import 'package:flutter/widgets.dart';

/// Responsive + adaptive layer, ported 1:1 from the prototype's `adaptive.css`
/// (Balsm DS Tier 4, §6.5).
///
/// One scale, all stacks: the breakpoints mirror the design's `--bp` tokens, so
/// the same numbers map to Flutter [LayoutBuilder], Tailwind sm/md/lg/xl, and
/// CSS `@media`/`@container`.
///
/// Every primitive here keys off the **local** [BoxConstraints] (via
/// [LayoutBuilder]), not the viewport — the Flutter equivalent of CSS container
/// queries. A component therefore adapts inside a narrow tablet pane or
/// foldable, not just at the window edge.
///
/// RTL: layouts use [Row]/[Wrap] under the ambient [Directionality], so they
/// mirror automatically under `dir=rtl`. Test each breakpoint both directions.
class Bp {
  Bp._();
  static const xs = 375.0;
  static const sm = 480.0;
  static const md = 768.0;
  static const lg = 1024.0;
  static const xl = 1280.0;
}

/// Design spacing scale (`--space-*`, 4/8 rhythm).
class Space {
  Space._();
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 20.0;
  static const s6 = 24.0;
  static const s8 = 32.0;
  static const s10 = 40.0;
  static const s12 = 48.0;
  static const s16 = 64.0;
  static const s20 = 80.0;
  static const s24 = 96.0;
}

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// Heuristic for a coarse (touch) primary pointer — bump touch targets to 48
  /// per `@media (pointer: coarse)`. Flutter exposes no pointer-kind query, so
  /// we treat narrow widths as touch-first.
  bool get coarsePointer => screenWidth < Bp.md;
}

/// `.adaptive-cluster` — items flow and wrap onto new lines, never h-scroll.
class AdaptiveCluster extends StatelessWidget {
  const AdaptiveCluster({
    super.key,
    required this.children,
    this.gap = Space.s3,
    this.runGap,
    this.alignment = WrapAlignment.start,
    this.crossAxisAlignment = WrapCrossAlignment.center,
  });
  final List<Widget> children;
  final double gap;
  final double? runGap;
  final WrapAlignment alignment;
  final WrapCrossAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: gap,
        runSpacing: runGap ?? gap,
        alignment: alignment,
        crossAxisAlignment: crossAxisAlignment,
        children: children,
      );
}

/// `.adaptive-row` — stacks as a column, becomes a row once the CONTAINER
/// passes [breakpoint] (sm/480 by default). Field↔field, label↔control,
/// toolbars. Each child is wrapped in [Expanded] in row mode unless [flex] is
/// set to false.
class AdaptiveRow extends StatelessWidget {
  const AdaptiveRow({
    super.key,
    required this.children,
    this.breakpoint = Bp.sm,
    this.gap = Space.s4,
    this.expand = true,
    this.rowCrossAxisAlignment = CrossAxisAlignment.center,
  });
  final List<Widget> children;
  final double breakpoint;
  final double gap;
  final bool expand;
  final CrossAxisAlignment rowCrossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final row = c.maxWidth >= breakpoint;
      final sep = SizedBox(width: row ? gap : 0, height: row ? 0 : gap);
      final laid = <Widget>[];
      for (var i = 0; i < children.length; i++) {
        if (i > 0) laid.add(sep);
        laid.add(row && expand ? Expanded(child: children[i]) : children[i]);
      }
      return row
          ? Row(crossAxisAlignment: rowCrossAxisAlignment, children: laid)
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: laid);
    });
  }
}

/// Variants of [AdaptiveSplit].
enum SplitMode {
  /// aside (fixed) + content (flex) — the default master/detail.
  start,

  /// content (flex) + aside (fixed).
  end,

  /// even halves (1fr 1fr).
  even,
}

/// `.adaptive-split` — single column until the CONTAINER passes md (768), then
/// a two-pane grid. Patient app phone→tablet, master/detail.
class AdaptiveSplit extends StatelessWidget {
  const AdaptiveSplit({
    super.key,
    required this.primary,
    required this.aside,
    this.mode = SplitMode.start,
    this.breakpoint = Bp.md,
    this.asideWidth = 288, // 18rem
    this.gap = Space.s6,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  /// Main content pane (the flex side).
  final Widget primary;

  /// Secondary pane (the fixed side, or the other half in [SplitMode.even]).
  final Widget aside;
  final SplitMode mode;
  final double breakpoint;
  final double asideWidth;
  final double gap;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < breakpoint) {
        // Stacked: primary first, then aside (source order).
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [primary, SizedBox(height: gap), aside],
        );
      }
      final sep = SizedBox(width: gap);
      final List<Widget> panes = switch (mode) {
        SplitMode.start => [
            SizedBox(width: asideWidth, child: aside),
            sep,
            Expanded(child: primary),
          ],
        SplitMode.end => [
            Expanded(child: primary),
            sep,
            SizedBox(width: asideWidth, child: aside),
          ],
        SplitMode.even => [
            Expanded(child: primary),
            sep,
            Expanded(child: aside),
          ],
      };
      return Row(crossAxisAlignment: crossAxisAlignment, children: panes);
    });
  }
}

/// `.adaptive-grid` — fills as many equal columns as fit, content-led
/// (`repeat(auto-fill, minmax(col-min, 1fr))`). Card decks, tiles, dashboards.
/// No breakpoints to maintain — column count follows the container width.
class AdaptiveGrid extends StatelessWidget {
  const AdaptiveGrid({
    super.key,
    required this.children,
    this.colMin = 256, // 16rem
    this.gap = Space.s5,
    this.runGap,
    this.maxColumns,
  });
  final List<Widget> children;
  final double colMin;
  final double gap;
  final double? runGap;
  final int? maxColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth.isFinite ? c.maxWidth : Bp.sm;
      var cols = ((w + gap) / (colMin + gap)).floor();
      cols = cols.clamp(1, maxColumns ?? 1 << 30);
      final itemW = (w - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: runGap ?? gap,
        children: children.map((child) => SizedBox(width: itemW, child: child)).toList(),
      );
    });
  }
}

/// Centers and width-caps long-form content on large screens so a touch-first
/// layout never stretches edge-to-edge on desktop/web.
class ContentColumn extends StatelessWidget {
  const ContentColumn({super.key, required this.child, this.maxWidth = 640});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      );
}
