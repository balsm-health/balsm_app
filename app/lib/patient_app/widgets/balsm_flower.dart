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
      Opacity(opacity: opacity, child: CustomPaint(size: Size.square(size), painter: _FlowerPainter()));
}

class _FlowerPainter extends CustomPainter {
  static const _petals = [
    T.petalEmerald, T.petalBlue, T.petalMint, T.petalViolet, T.petalAqua,
  ];
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
      canvas.drawOval(rect, Paint()..color = _petals[i]..isAntiAlias = true);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_FlowerPainter old) => false;
}
