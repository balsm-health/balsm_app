import 'package:flutter/material.dart';
import '../_tokens.dart';

// Not wired in P001 (no daily check-in). Lifted for P002 forward-compat.
enum BalsmMood { happy, neutral, sad, veryHappy, verySad }

/// SVG-arc mood face per design.md §3 (no emoji).
/// Not used in P001 — forward-compat for P002 daily check-in.
class BalsmMoodFace extends StatelessWidget {
  const BalsmMoodFace({
    super.key,
    required this.mood,
    this.size = 34,
    this.selected = false,
  });

  final BalsmMood mood;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _MoodFacePainter(
        mood: mood,
        selected: selected,
        accent: BalsmColors.appAccent,
      ),
    );
  }
}

class _MoodFacePainter extends CustomPainter {
  const _MoodFacePainter({
    required this.mood,
    required this.selected,
    required this.accent,
  });

  final BalsmMood mood;
  final bool selected;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final center = Offset(r, r);
    final faceColor = selected ? accent : BalsmColors.ink300;
    final paint = Paint()
      ..color = faceColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.07
      ..strokeCap = StrokeCap.round;

    // Face circle
    canvas.drawCircle(center, r * 0.9, paint);

    // Eyes
    final eyeY = r * 0.7;
    final eyeX = r * 0.38;
    final eyePaint = Paint()
      ..color = faceColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(r - eyeX, eyeY), r * 0.09, eyePaint);
    canvas.drawCircle(Offset(r + eyeX, eyeY), r * 0.09, eyePaint);

    // Mouth arc
    final mouthRect = Rect.fromCenter(
      center: Offset(r, r * 1.1),
      width: r * 0.9,
      height: r * 0.6,
    );
    final (startAngle, sweepAngle) = _mouthAngles;
    canvas.drawArc(mouthRect, startAngle, sweepAngle, false, paint);
  }

  (double, double) get _mouthAngles {
    switch (mood) {
      case BalsmMood.veryHappy:
        return (0.1, 2.9); // big smile
      case BalsmMood.happy:
        return (0.2, 2.7);
      case BalsmMood.neutral:
        return (0.0, 3.14); // flat line
      case BalsmMood.sad:
        return (-0.4, -2.3);
      case BalsmMood.verySad:
        return (-0.3, -2.6);
    }
  }

  @override
  bool shouldRepaint(_MoodFacePainter old) =>
      old.mood != mood || old.selected != selected;
}
