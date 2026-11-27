import 'package:flutter/widgets.dart';

import '../../core.dart' show AppColors;

import 'app_colors.dart' show AppColors;

import 'balsm_kit.dart' show AppColors;

import 'tokens.dart' show AppColors;

/// The shared elevation scale (warm, soft), plus the floating-tab shadow and the brand glow.
class AppShadows {
  AppShadows._();

  static const List<BoxShadow> xs = [
    BoxShadow(color: Color(0x0F14202B), blurRadius: 2, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> sm = [
    BoxShadow(color: Color(0x0F14202B), blurRadius: 6, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x0A14202B), blurRadius: 2, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> md = [
    BoxShadow(color: Color(0x1414202B), blurRadius: 20, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x0A14202B), blurRadius: 6, offset: Offset(0, 2)),
  ];

  /// `--shadow-lg`: floating surfaces over content, such as a toast.
  static const List<BoxShadow> lg = [
    BoxShadow(color: Color(0x1A14202B), blurRadius: 40, offset: Offset(0, 18)), // rgba(20,32,43,.10)
    BoxShadow(color: Color(0x0F14202B), blurRadius: 12, offset: Offset(0, 4)), // rgba(20,32,43,.06)
  ];

  /// Tab-bar check-in disc (compact): `0 6px 16px rgba(31,45,61,.28)`.
  static const List<BoxShadow> fab = [
    BoxShadow(color: Color(0x471F2D3D), blurRadius: 16, offset: Offset(0, 6)),
  ];

  /// Resting card elevation (`--v2-card-sh`): a hairline plus a soft wide wash.
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0A14202B), blurRadius: 2, offset: Offset(0, 1)), // rgba(20,32,43,.04)
    BoxShadow(color: Color(0x0B14202B), blurRadius: 24, offset: Offset(0, 8)), // rgba(20,32,43,.045)
  ];

  /// Brand glow under a call-to-action hero card ([AppColors.hueBlue] at 22%).
  static const List<BoxShadow> brand = [
    BoxShadow(color: Color(0x381283FF), blurRadius: 24, offset: Offset(0, 8)),
  ];
}
