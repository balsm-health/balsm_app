import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import '../tokens.dart';

class ChartSeries {
  const ChartSeries(this.data, this.color);
  final List<double> data;
  final Color color;

  /// By value: the painter compares series to decide whether to repaint, and
  /// callers rebuild these from a fresh list on every read.
  @override
  bool operator ==(Object other) => other is ChartSeries && other.color == color && listEquals(other.data, data);

  @override
  int get hashCode => Object.hash(color, Object.hashAll(data));
}

/// Minimal multi-series line chart (home.jsx LineChart). RTL mirrors the x-axis.
class LineChartView extends StatelessWidget {
  const LineChartView({super.key, required this.series, this.rtl = false, this.height = 96});
  final List<ChartSeries> series;
  final bool rtl;
  final double height;
  @override
  Widget build(BuildContext context) => RepaintBoundary(
        // The chart is a leaf that changes far less often than the screens it
        // sits in; its own layer keeps a sibling rebuild from repainting it.
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(painter: _LinePainter(series, rtl)),
        ),
      );
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.series, this.rtl);
  final List<ChartSeries> series;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    const yPad = 8.0;
    final all = series.expand((s) => s.data).toList();
    final min = all.reduce((a, b) => a < b ? a : b);
    final max = all.reduce((a, b) => a > b ? a : b);
    final range = (max - min) == 0 ? 1 : (max - min);
    final n = series.first.data.length;

    double x(int i) {
      final r = n == 1 ? 0.5 : i / (n - 1);
      return (rtl ? 1 - r : r) * (size.width - 16) + 8;
    }

    double y(double v) => yPad + (1 - (v - min) / range) * (size.height - yPad * 2);

    // mid gridline
    final grid = Paint()
      ..color = T.ink100
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), grid);

    for (final s in series) {
      final line = Paint()
        ..color = s.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;
      final path = Path();
      for (var i = 0; i < s.data.length; i++) {
        final p = Offset(x(i), y(s.data[i]));
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(path, line);

      final dot = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      final dotStroke = Paint()
        ..color = s.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      final lastIdx = rtl ? 0 : n - 1;
      for (var i = 0; i < s.data.length; i++) {
        final p = Offset(x(i), y(s.data[i]));
        final r = i == lastIdx ? 4.0 : 2.5;
        canvas.drawCircle(p, r, dot);
        canvas.drawCircle(p, r, dotStroke);
      }
    }
  }

  /// `=> true` repainted on every parent repaint, and [paint] walks every
  /// series to find the min/max before it draws anything.
  @override
  bool shouldRepaint(_LinePainter old) => old.rtl != rtl || !listEquals(old.series, series);
}
