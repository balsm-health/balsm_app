import 'dart:math' as math;

/// WHO body-mass-index category.
enum BmiCategory { underweight, normal, overweight, obese }

/// Body mass index and its clinical classification.
///
/// Both the formula and the category cut-offs used to live inside a widget's
/// `_bmi` getter, interleaved with colours and a gauge offset. They are
/// clinical facts, not presentation: the same numbers decide what a summary
/// card, an export and a trend chart each say, and a threshold edited in one
/// screen would silently disagree with the others.
///
/// Presentation keeps what is genuinely presentation — which colour a category
/// gets, and where the needle sits.
class Bmi {
  const Bmi._(this.value, this.category);

  /// kg/m², unrounded. Format at the edge that displays it.
  final double value;
  final BmiCategory category;

  /// WHO cut-offs (kg/m²). Adult, non-pregnant. Boundaries are exclusive
  /// upper bounds: 25.0 is overweight, not normal.
  static const underweightBelow = 18.5;
  static const normalBelow = 25.0;
  static const overweightBelow = 30.0;

  /// Null when either measurement is missing, non-positive, or produces a
  /// non-finite result — an absent BMI is a normal state (nothing entered
  /// yet), not an error to surface.
  static Bmi? fromMeasurements({required double? weightKg, required double? heightCm}) {
    if (weightKg == null || heightCm == null) return null;
    if (weightKg <= 0 || heightCm <= 0) return null;
    final metres = heightCm / 100;
    final value = weightKg / math.pow(metres, 2);
    if (!value.isFinite) return null;
    return Bmi._(value, _classify(value));
  }

  static BmiCategory _classify(double value) {
    if (value < underweightBelow) return BmiCategory.underweight;
    if (value < normalBelow) return BmiCategory.normal;
    if (value < overweightBelow) return BmiCategory.overweight;
    return BmiCategory.obese;
  }

  @override
  bool operator ==(Object other) => other is Bmi && other.value == value && other.category == category;

  @override
  int get hashCode => Object.hash(value, category);
}
