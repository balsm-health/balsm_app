// ignore_for_file: constant_identifier_names

/// Bundled asset paths — the single source of truth for every `assets/…`
/// reference in the patient app. Keep in sync with the `flutter.assets` list
/// in `pubspec.yaml`.
class Assets {
  Assets._();

  static const _brand = 'assets/brand';
  static const _body = 'assets/body';

  /// Icon-only watercolor ring mark (`Balsm-Core/brand/icon.svg`).
  static const brand_icon = '$_brand/icon.svg';

  /// The same mark as one solid white silhouette (`icon-mono-white.svg`),
  /// for watermarks on an accent fill. The design used to invert the colour
  /// mark with a filter and now ships this asset instead — inverting flattened
  /// the ring's overlaps, this keeps them.
  static const brand_icon_mono_white = '$_brand/icon-mono-white.svg';

  /// Vertical lockup — mark over بلسم / Balsm.health (`logo-vertical.svg`).
  static const brand_logo_vertical = '$_brand/logo-vertical.svg';

  /// Watercolor wash for splash / welcome. Lives in core so the kit widget
  /// and the app shell share one file.
  static const brand_background = 'packages/core/assets/brand/balsm-background.png';

  /// Body-map figure for the pain report. [gender] is `male` | `female`,
  /// [view] is `front` | `back`.
  static String bodyFigure(String gender, String view) => '$_body/${gender}_$view.svg';

  static const body_muscles_male = '$_body/muscles_male.svg';
}
