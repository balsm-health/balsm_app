import 'package:app/balsm_app/screens/trend_series.dart';
import 'package:core/core.dart';
import 'package:family/family.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:self_report/self_report.dart';

/// The Trends series (mother-child.jsx `mcSeries` / `mcTrendCount`): check-ins
/// and growth entries become one oldest-first series per metric. The readings
/// are invented by the test.
void main() {
  CheckIn at(String id, DateTime when, {Vitals vitals = const Vitals(), int pain = 0}) => CheckIn(
        id: CheckInId.value(id),
        healthProfileId: const HealthProfileId.value('hp-1'),
        recordedAt: when,
        painLevel: PainLevel(pain),
        painSites: const {},
        symptoms: const {},
        vitals: vitals,
      );

  GrowthEntry growth(String id, DateTime on, {double? kg, double? cm}) => GrowthEntry(
        id: GrowthEntryId.value(id),
        measuredOn: on,
        createdAt: on,
        weightKg: kg,
        heightCm: cm,
      );

  test('nothing logged, no metrics', () => expect(trendSeries(const []), isEmpty));

  test('pairs blood pressure, skips half readings, and leaves out metrics with nothing', () {
    final s = trendSeries([
      at('b', DateTime(2026, 11, 2), vitals: const Vitals(systolic: 120)),
      at('a', DateTime(2026, 11), vitals: const Vitals(systolic: 118, diastolic: 76), pain: 3),
    ]);

    expect(s.keys, [TrendMetric.bp, TrendMetric.pain]);
    expect(s[TrendMetric.bp]!.single.value2, 76);
    expect(s[TrendMetric.pain]!.single.value, 3);
  });

  test('growth adds height and merges its weight with check-ins in date order', () {
    final s = trendSeries(
      [at('c', DateTime(2026, 11, 10), vitals: const Vitals(weightKg: 15.2))],
      growth: [
        growth('g2', DateTime.utc(2026, 11, 12), cm: 101),
        growth('g1', DateTime.utc(2026, 11), kg: 14.8, cm: 100),
      ],
    );

    expect(s.keys, [TrendMetric.weight, TrendMetric.height]);
    expect(s[TrendMetric.weight]!.map((p) => p.value), [14.8, 15.2]);
    expect(s[TrendMetric.height]!.map((p) => p.value), [100, 101]);
  });
}
