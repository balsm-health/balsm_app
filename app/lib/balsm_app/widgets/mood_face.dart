import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Simple line-drawn mood face (1=rough … 5=great). Mouth curvature and brow
/// follow the level; stroke uses [color].
class MoodFace extends StatelessWidget {
  const MoodFace({super.key, required this.level, this.size = 34, required this.color});
  final int level; // 1..5
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _MoodPainter(level, color));
}

class _MoodPainter extends CustomPainter {
  _MoodPainter(this.level, this.color);
  final int level;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.07
      ..strokeCap = StrokeCap.round;
    final c = Offset(w / 2, w / 2);
    canvas.drawCircle(c, w / 2 - stroke.strokeWidth / 2, stroke);

    // eyes
    final eyeR = w * 0.045;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.34, w * 0.40), eyeR, fill);
    canvas.drawCircle(Offset(w * 0.66, w * 0.40), eyeR, fill);

    // mouth: curvature from frown (level 1) to smile (level 5)
    final t = (level - 3) / 2.0; // -1 .. 1
    final mouthY = w * 0.64;
    final curve = w * 0.16 * t;
    final path = Path()
      ..moveTo(w * 0.34, mouthY - (t < 0 ? curve : 0))
      ..quadraticBezierTo(w * 0.5, mouthY + curve * 1.6, w * 0.66, mouthY - (t < 0 ? curve : 0));
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(_MoodPainter old) => old.level != level || old.color != color;
}

/// A bigger mood face button used in the report flow's mood grid.
class MoodFaceButton extends StatelessWidget {
  const MoodFaceButton({super.key, required this.level, required this.color, this.size = 34});
  final int level;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) =>
      Transform.rotate(angle: 0 * math.pi, child: MoodFace(level: level, size: size, color: color));
}
