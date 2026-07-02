import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../assets.dart';
import '../tokens.dart';

/// The official Balsm five-petal flower mark, rendered from the bundled brand
/// vector asset (`assets/brand/icon.svg`, mirrored from Balsm-Core/brand).
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

/// Brand loading spinner (`.b-petal-spinner`) — the canonical design-system
/// loader: five colored petals arranged in a ring that rotates over 3.6s while
/// each pulses .35 → 1, staggered by a fifth of the cycle. Geometry ported from
/// the design CSS (28% petal, `transform-origin 50% 178%` → 0.358·S orbit).
/// Under reduced motion it holds still at .9 opacity (design's "healthcare
/// stillness").
class PetalSpinner extends StatefulWidget {
  const PetalSpinner({super.key, this.size = 48});
  final double size;
  @override
  State<PetalSpinner> createState() => _PetalSpinnerState();
}

class _PetalSpinnerState extends State<PetalSpinner> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3600))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // `b-petal-pulse`: triangle wave peaking at 40% of the cycle (.35 → 1 → .35).
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
          painter: _PetalRingPainter(0, const [0.9, 0.9, 0.9, 0.9, 0.9]),
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
            painter: _PetalRingPainter(
              t * 2 * math.pi,
              [for (var i = 0; i < 5; i++) _pulse(t + i * 0.2)],
            ),
          );
        },
      ),
    );
  }
}

/// Draws the five-petal ring (`.b-petal-spinner`): five circles at 72° steps,
/// orbit radius 0.358·S, petal radius 0.14·S, each in its brand hue.
class _PetalRingPainter extends CustomPainter {
  _PetalRingPainter(this.rotation, this.opacities);
  final double rotation;
  final List<double> opacities;

  // Petal order (clockwise from top): emerald → blue → mint → violet → aqua.
  static const _colors = [
    T.petalEmerald, T.petalBlue, T.petalMint, T.petalViolet, T.petalAqua,
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
        c, pr, Paint()
          ..color = _colors[i].withValues(alpha: opacities[i])
          ..isAntiAlias = true,
      );
    }
  }

  @override
  bool shouldRepaint(_PetalRingPainter old) =>
      old.rotation != rotation || old.opacities != opacities;
}
