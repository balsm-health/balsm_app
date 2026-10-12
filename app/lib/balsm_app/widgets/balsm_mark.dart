import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../assets.dart';
import '../tokens.dart';

/// The official Balsm five-ribbon ring mark (`assets/brand/icon.svg`), ported
/// from the design project's `petalmark.jsx` / `assets/icon.svg`.
class BalsmFlower extends StatelessWidget {
  const BalsmFlower({super.key, this.size = 92, this.opacity = 1});
  final double size;
  final double opacity;
  @override
  Widget build(BuildContext context) => Opacity(
        opacity: opacity,
        child: SvgPicture.asset(Assets.brand_icon, width: size, height: size),
      );
}

/// Brand loading spinner (`.b-mark-spinner`) — the canonical design-system
/// loader: five colored dots arranged in a ring that rotates over 3.6s while
/// each pulses .35 → 1, staggered by a fifth of the cycle. Geometry ported from
/// the design CSS (28% dot, `transform-origin 50% 178%` → 0.358·S orbit).
/// Under reduced motion it holds still at .9 opacity (design's "healthcare
/// stillness").
class MarkSpinner extends StatefulWidget {
  const MarkSpinner({super.key, this.size = 48});
  final double size;
  @override
  State<MarkSpinner> createState() => _MarkSpinnerState();
}

class _MarkSpinnerState extends State<MarkSpinner> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // `b-mark-pulse`: triangle wave peaking at 40% of the cycle (.35 → 1 → .35).
  double _pulse(double x) {
    x %= 1.0;
    return x < 0.4 ? 0.35 + 0.65 * (x / 0.4) : 1.0 - 0.65 * ((x - 0.4) / 0.6);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce) {
      return RepaintBoundary(
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: _MarkRingPainter(0, const [0.9, 0.9, 0.9, 0.9, 0.9]),
        ),
      );
    }
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final t = _c.value;
          return CustomPaint(
            size: Size.square(widget.size),
            painter: _MarkRingPainter(
              t * 2 * math.pi,
              [for (var i = 0; i < 5; i++) _pulse(t + i * 0.2)],
            ),
          );
        },
      ),
    );
  }
}

/// Draws the five-dot ring (`.b-mark-spinner`): five circles at 72° steps,
/// orbit radius 0.358·S, dot radius 0.14·S, each in its brand hue.
class _MarkRingPainter extends CustomPainter {
  _MarkRingPainter(this.rotation, this.opacities);
  final double rotation;
  final List<double> opacities;

  // Dot order (clockwise from top): emerald → blue → mint → violet → aqua.
  // NOTE: this is the retired five-petal flower's order. brand/icon.svg
  // paints the current mark aqua → blue → emerald → violet → mint. Changing
  // it here is a visual change with goldens attached — left as-is on purpose.
  static const _colors = [
    T.hueEmerald,
    T.hueBlue,
    T.hueMint,
    T.hueViolet,
    T.hueAqua,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    // transform-origin 50% / 178% of a 28% box ≈ the container centre.
    final center = Offset(size.width / 2, s * 0.4984);
    final orbit = 0.3584 * s;
    final pr = 0.14 * s;
    for (var i = 0; i < 5; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / 5 + rotation;
      final c = center + Offset(orbit * math.cos(a), orbit * math.sin(a));
      canvas.drawCircle(
        c,
        pr,
        Paint()
          ..color = _colors[i].withValues(alpha: opacities[i])
          ..isAntiAlias = true,
      );
    }
  }

  @override
  bool shouldRepaint(_MarkRingPainter old) => old.rotation != rotation || old.opacities != opacities;
}
