import 'package:flutter_test/flutter_test.dart';
import 'package:self_report/self_report.dart';

/// Vitals is a value: the same readings are the same vitals, whichever
/// instance holds them.
void main() {
  test('the same readings are equal, with equal hashes', () {
    const a = Vitals(systolic: 120, diastolic: 80, heartRate: 72);
    final b = const Vitals().copyWith(systolic: 120, diastolic: 80, heartRate: 72);
    expect(identical(a, b), isFalse);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  test('any differing reading makes them unequal', () {
    const base = Vitals(systolic: 120, diastolic: 80, heartRate: 72, spo2: 98, weightKg: 70.5);
    for (final other in [
      base.copyWith(systolic: 121),
      base.copyWith(diastolic: 81),
      base.copyWith(heartRate: 73),
      base.copyWith(spo2: 97),
      base.copyWith(weightKg: 70.6),
      base.copyWith(temperature: 37),
      base.copyWith(glucoseFasting: 95),
      base.copyWith(glucosePostMeal: 140),
      base.copyWith(glucoseRandom: 110),
    ]) {
      expect(other, isNot(base));
    }
  });

  test('a fresh empty snapshot equals Vitals.empty', () {
    expect(const Vitals(), Vitals.empty);
    // ignore: prefer_const_constructors
    expect(Vitals(), Vitals.empty);
  });
}
