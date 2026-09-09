import 'package:flutter_test/flutter_test.dart';
import 'package:profile/profile.dart';

/// WHO cut-offs are exclusive upper bounds, so every boundary value belongs to
/// the category above it. Off-by-one here mislabels a patient's health status.
void main() {
  Bmi? bmi(double kg, double cm) => Bmi.fromMeasurements(weightKg: kg, heightCm: cm);

  /// Weight (kg) that lands exactly on [target] BMI at 1.75 m.
  double weightFor(double target) => target * 1.75 * 1.75;

  group('classification', () {
    test('below 18.5 is underweight', () {
      expect(bmi(weightFor(18.49), 175)!.category, BmiCategory.underweight);
    });

    test('exactly 18.5 is normal, not underweight', () {
      expect(bmi(weightFor(18.5), 175)!.category, BmiCategory.normal);
    });

    test('exactly 25 is overweight, not normal', () {
      expect(bmi(weightFor(25.0), 175)!.category, BmiCategory.overweight);
    });

    test('exactly 30 is obese, not overweight', () {
      expect(bmi(weightFor(30.0), 175)!.category, BmiCategory.obese);
    });

    test('just under 25 is still normal', () {
      expect(bmi(weightFor(24.99), 175)!.category, BmiCategory.normal);
    });
  });

  group('value', () {
    test('height is read as centimetres, not metres', () {
      // 70 kg at 175 cm is ~22.9. Treating 175 as metres would give ~0.002.
      expect(bmi(70, 175)!.value, closeTo(22.86, 0.01));
    });
  });

  group('absent rather than wrong', () {
    test('a missing measurement yields null', () {
      expect(Bmi.fromMeasurements(weightKg: 70, heightCm: null), isNull);
      expect(Bmi.fromMeasurements(weightKg: null, heightCm: 175), isNull);
    });

    test('zero or negative input yields null instead of infinity', () {
      expect(bmi(70, 0), isNull, reason: 'division by zero must not reach the UI');
      expect(bmi(0, 175), isNull);
      expect(bmi(-70, 175), isNull);
    });
  });
}
