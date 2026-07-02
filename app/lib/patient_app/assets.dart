// ignore_for_file: constant_identifier_names

/// Bundled asset paths — the single source of truth for every `assets/…`
/// reference in the patient app. Keep in sync with the `flutter.assets` list
/// in `pubspec.yaml`.
class Assets {
  Assets._();

  static const _brand = 'assets/brand';
  static const _body = 'assets/body';

  /// The official Balsm five-petal flower mark (mirrored from Balsm-Core/brand).
  static const brand_icon = '$_brand/icon.svg';

  /// Body-map figure for the pain report. [gender] is `male` | `female`,
  /// [view] is `front` | `back`.
  static String bodyFigure(String gender, String view) => '$_body/${gender}_$view.svg';

  static const body_muscles_male = '$_body/muscles_male.svg';
}
