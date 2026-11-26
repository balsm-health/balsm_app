import 'package:flutter/painting.dart';

import 'app_colors.dart';
import 'font_sizes.dart';

/// Typography helpers. `ar` switches the family to IBM Plex Sans Arabic.
///
/// Families are **bundled** (`assets/fonts/`, declared in pubspec), not fetched
/// at runtime. The design system self-hosts for the same reason its README
/// gives: "offline-default is value #1 … nothing in the type stack touches the
/// network at runtime". Loading these from Google would mean a signal-less
/// device falls back to system glyphs, and every cold start reports the user
/// to a third party — both at odds with what this product claims to be.
class Typo {
  Typo._();

  /// Design `--font-display` / `--font-arabic`.
  static const _familyDisplay = 'Montserrat';

  /// Design `--font-body`.
  static const _familyBody = 'IBM Plex Sans';

  /// Design `--font-arabic` — one family for both roles in Arabic.
  static const _familyArabic = 'IBM Plex Sans Arabic';

  /// Design `--font-mono` — numerics, IDs, batch codes.
  static const _familyMono = 'IBM Plex Mono';

  /// The display family for [ar] with nothing else set: the base for a custom heading style.
  static TextStyle displayFace(bool ar) => TextStyle(fontFamily: ar ? _familyArabic : _familyDisplay);

  /// The body family for [ar] with nothing else set: the base for a custom text style.
  static TextStyle bodyFace(bool ar) => TextStyle(fontFamily: ar ? _familyArabic : _familyBody);
  static TextStyle mono() => const TextStyle(fontFamily: _familyMono);

  static TextStyle display({bool ar = false}) => displayFace(ar).copyWith(
        fontWeight: FontWeight.w800,
        fontSize: FontSizes.display,
        height: 1.1,
        letterSpacing: -0.64,
        color: AppColors.textPrimary,
      );
  static TextStyle title({bool ar = false}) => displayFace(ar).copyWith(
        fontWeight: FontWeight.w700,
        fontSize: FontSizes.title,
        height: 1.18,
        letterSpacing: -0.4,
        color: AppColors.textPrimary,
      );
  static TextStyle heading({bool ar = false}) => displayFace(ar).copyWith(
        fontWeight: FontWeight.w700,
        fontSize: FontSizes.heading,
        height: 1.25,
        letterSpacing: -0.21,
        color: AppColors.textPrimary,
      );
  static TextStyle subhead({bool ar = false}) => displayFace(ar)
      .copyWith(fontWeight: FontWeight.w600, fontSize: FontSizes.subhead, height: 1.3, color: AppColors.textPrimary);
  static TextStyle body({bool ar = false}) =>
      bodyFace(ar).copyWith(fontSize: FontSizes.body, height: 1.55, color: AppColors.textSecondary);
  static TextStyle bodySm({bool ar = false}) =>
      bodyFace(ar).copyWith(fontSize: FontSizes.bodySm, height: 1.5, color: AppColors.textSecondary);
  static TextStyle meta({bool ar = false}) =>
      bodyFace(ar).copyWith(fontSize: FontSizes.meta, height: 1.4, color: AppColors.textTertiary);
  static TextStyle eyebrow(Color color, {bool ar = false}) => bodyFace(ar)
      .copyWith(fontSize: FontSizes.eyebrow, fontWeight: FontWeight.w700, letterSpacing: ar ? 0 : 1.76, color: color);
  static TextStyle num({
    double size = FontSizes.body,
    FontWeight weight = FontWeight.w600,
    Color color = AppColors.textPrimary,
  }) =>
      mono().copyWith(fontSize: size, fontWeight: weight, color: color);
}
