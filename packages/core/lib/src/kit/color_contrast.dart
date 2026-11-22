import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'app_colors.dart';

/// Picks legible foreground colours by measuring contrast (WCAG relative luminance).
class ColorContrast {
  ColorContrast._();

  /// Text or icon colour that stays legible on [fill].
  ///
  /// Picks ink900 or white by measuring, rather than assuming white reads on
  /// anything: white on mint is 2.28:1 and on sun 1.93:1 — invisible by the
  /// standard — while ink900 on those is 7.24 and 8.57. On violet and blue it
  /// is the other way round. Measuring means a new accent cannot quietly ship
  /// an illegible button.
  static Color onFill(Color fill) =>
      _contrast(AppColors.ink900, fill) >= _contrast(AppColors.white, fill) ? AppColors.ink900 : AppColors.white;

  static double _relativeLuminance(Color c) {
    double channel(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
  }

  static double _contrast(Color a, Color b) {
    final la = _relativeLuminance(a);
    final lb = _relativeLuminance(b);
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }
}
