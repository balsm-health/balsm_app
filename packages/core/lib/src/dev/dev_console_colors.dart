import 'package:flutter/painting.dart';

import '../kit/app_colors.dart';

/// Colours of the developer console (`ServerSelectorScreen`): a dark terminal look that only appears in
/// development builds, so it is kept apart from the product palette in [AppColors].
class DevConsoleColors {
  DevConsoleColors._();

  static const Color background = AppColors.nearBlack;
  static const panel = Color(0xFF3A3A34);

  /// The lime accent of the console.
  static const accent = Color(0xFFA3FF6E);

  static const text = Color(0xFFC8C8BE);
  static const textMuted = Color(0xFF6E6E64);
  static const textDim = Color(0xFF888888);
  static const error = Color(0xFFF87171);
  static const warning = Color(0xFFFBBF24);
  static const Color chipFill = AppColors.white12;
  static const shadow = Color(0x40000000);
}
