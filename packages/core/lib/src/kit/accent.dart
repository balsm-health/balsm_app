import 'package:flutter/widgets.dart';

import 'app_colors.dart';

/// The accent hue that tints CTAs, rings, active states. Default = blue.
class Accent {
  const Accent(this.main, this.d, this.bg, this.shadow);
  final Color main;
  final Color d; // darker (pressed)
  final Color bg; // wash
  final Color shadow;

  static const blue = Accent(AppColors.hueBlue, AppColors.hueBlue600, AppColors.hueBlue50, Color(0x421283FF));
  static const aqua = Accent(AppColors.hueAqua, AppColors.hueAqua600, AppColors.hueAqua50, Color(0x4202BBB5));
  static const emerald =
      Accent(AppColors.hueEmerald, AppColors.hueEmerald600, AppColors.hueEmerald50, Color(0x4201C4A2));
  static const violet = Accent(AppColors.hueViolet, AppColors.hueViolet600, AppColors.hueViolet50, Color(0x42724DD0));
  static const mint = Accent(AppColors.hueMint600, Color(0xFF2FA552), AppColors.hueMint50, Color(0x4D55D77F));

  List<BoxShadow> get boxShadow => [BoxShadow(color: shadow, blurRadius: 22, offset: const Offset(0, 8))];
}
