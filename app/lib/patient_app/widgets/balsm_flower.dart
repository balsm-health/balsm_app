import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../tokens.dart';

/// The official Balsm five-petal flower mark, drawn from the prototype's
/// inline SVG (5 rotated ellipses).
class BalsmFlower extends StatelessWidget {
  const BalsmFlower({super.key, this.size = 92, this.opacity = 1});
  final double size;
  final double opacity;
  @override
  Widget build(BuildContext context) =>
      Opacity(opacity: opacity, child: CustomPaint(size: Size.square(size), painter: const _FlowerPainter()));
}

const _petalColors = [
  T.petalEmerald, T.petalBlue, T.petalMint, T.petalViolet, T.petalAqua,
];

class _FlowerPainter extends CustomPainter {
  const _FlowerPainter({this.opacities});
  /// Per-petal opacity (drives the [PetalSpinner] pulse). Null = fully opaque.
  final List<double>? opacities;
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    final center = Offset(size.width / 2, size.height * 0.46);
    final rx = 7.0 * s, ry = 13.0 * s, dy = -15.0 * s;
    for (var i = 0; i < 5; i++) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(i * 72 * math.pi / 180);
      final rect = Rect.fromCenter(center: Offset(0, dy), width: rx * 2, height: ry * 2);
      final o = opacities == null ? 1.0 : opacities![i];
      canvas.drawOval(rect, Paint()..color = _petalColors[i].withValues(alpha: o)..isAntiAlias = true);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_FlowerPainter old) => old.opacities != opacities;
}

/// Brand loading spinner (`.b-petal-spinner`): the flower rotates over 3.6s
/// while each petal pulses .35 → 1, staggered by a fifth of the cycle.
/// Spinning continues under reduced motion (loading indicators are exempt).
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

  // `b-petal-pulse`: triangle wave — valley .35, peak 1 at 40% of the cycle.
  double _pulse(double x) {
    x %= 1.0;
    return x < 0.4 ? 0.35 + 0.65 * (x / 0.4) : 1.0 - 0.65 * ((x - 0.4) / 0.6);
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final t = _c.value;
          final ops = [for (var i = 0; i < 5; i++) _pulse(t + i * 0.2)];
          return Transform.rotate(
            angle: t * 2 * math.pi,
            child: CustomPaint(
              size: Size.square(widget.size),
              painter: _FlowerPainter(opacities: ops),
            ),
          );
        },
      ),
    );
  }
}
