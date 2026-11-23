import 'package:flutter_test/flutter_test.dart';
import 'package:self_report/self_report.dart';

/// What a mistyped digit looks like versus a real reading, and where a reading
/// is worth highlighting.
void main() {
  group('plausibility', () {
    test('blood pressure: real readings pass, typos and swaps do not', () {
      expect(VitalLimits.bloodPressureOk(120, 80), isTrue);
      expect(VitalLimits.bloodPressureOk(60, 30), isTrue, reason: 'lower edge');
      expect(VitalLimits.bloodPressureOk(260, 160), isTrue, reason: 'upper edge');
      expect(VitalLimits.bloodPressureOk(20, 20), isFalse);
      expect(VitalLimits.bloodPressureOk(999, 999), isFalse);
      expect(VitalLimits.bloodPressureOk(80, 120), isFalse, reason: 'swapped');
      expect(VitalLimits.bloodPressureOk(120, 120), isFalse, reason: 'systolic must exceed diastolic');
      expect(VitalLimits.bloodPressureOk(null, 80), isFalse);
    });

    test('heart rate 30-220', () {
      for (final ok in [30, 72, 220]) {
        expect(VitalLimits.heartRateOk(ok), isTrue, reason: '$ok');
      }
      for (final bad in [0, 29, 221, 720]) {
        expect(VitalLimits.heartRateOk(bad), isFalse, reason: '$bad');
      }
    });

    test('SpO2 50-100, so 10 % and 101 % are typos', () {
      expect(VitalLimits.spo2Ok(98), isTrue);
      expect(VitalLimits.spo2Ok(50), isTrue);
      expect(VitalLimits.spo2Ok(100), isTrue);
      expect(VitalLimits.spo2Ok(10), isFalse);
      expect(VitalLimits.spo2Ok(101), isFalse);
    });

    test('glucose 20-600 mg/dL', () {
      expect(VitalLimits.glucoseOk(95), isTrue);
      expect(VitalLimits.glucoseOk(600), isTrue);
      expect(VitalLimits.glucoseOk(10), isFalse);
      expect(VitalLimits.glucoseOk(999), isFalse);
    });

    test('weight accepts a newborn, refuses nonsense', () {
      expect(VitalLimits.weightKgOk(3.4), isTrue, reason: 'newborn');
      expect(VitalLimits.weightKgOk(72.5), isTrue);
      expect(VitalLimits.weightKgOk(0), isFalse);
      expect(VitalLimits.weightKgOk(999.9), isFalse);
    });
  });

  group('elevated', () {
    test('blood pressure: high-normal or above', () {
      expect(VitalLimits.bloodPressureElevated(120, 80), isFalse);
      expect(VitalLimits.bloodPressureElevated(129, 84), isFalse);
      expect(VitalLimits.bloodPressureElevated(130, 80), isTrue);
      expect(VitalLimits.bloodPressureElevated(120, 85), isTrue);
    });

    test('glucose is judged by context', () {
      expect(VitalLimits.glucoseElevated(99, GlucoseContext.fasting), isFalse);
      expect(VitalLimits.glucoseElevated(130, GlucoseContext.fasting), isTrue,
          reason: 'was missed at the old 140 cut-off');
      expect(VitalLimits.glucoseElevated(139, GlucoseContext.postMeal), isFalse);
      expect(VitalLimits.glucoseElevated(140, GlucoseContext.postMeal), isTrue);
      expect(VitalLimits.glucoseElevated(150, GlucoseContext.random), isFalse);
      expect(VitalLimits.glucoseElevated(200, GlucoseContext.random), isTrue);
    });
  });
}
