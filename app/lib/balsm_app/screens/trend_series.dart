import 'package:family/family.dart';
import 'package:self_report/self_report.dart';

/// A metric the Trends charts can draw.
enum TrendMetric { bp, glucose, pain, weight, height }

/// One reading of a metric: [value], and for blood pressure the diastolic as
/// [value2].
class TrendPoint {
  const TrendPoint(this.at, this.value, [this.value2]);
  final DateTime at;
  final double value;
  final double? value2;
}

/// Every metric that has readings, each oldest first (mother-child.jsx
/// `mcSeries`): blood pressure, glucose, pain and weight from [checkIns];
/// weight and height from [growth] entries too, for a family member.
/// Metrics without a reading are left out, so `length` is how many a person
/// has (`mcTrendCount`).
Map<TrendMetric, List<TrendPoint>> trendSeries(
  Iterable<CheckIn> checkIns, {
  Iterable<GrowthEntry> growth = const [],
}) {
  final out = <TrendMetric, List<TrendPoint>>{};
  void put(TrendMetric m, TrendPoint p) => (out[m] ??= []).add(p);
  for (final c in checkIns) {
    final v = c.vitals;
    final at = c.recordedAt;
    // Systolic and diastolic are charted as a pair: a reading missing either
    // counts for neither.
    if (v.systolic != null && v.diastolic != null) {
      put(TrendMetric.bp, TrendPoint(at, v.systolic!.toDouble(), v.diastolic!.toDouble()));
    }
    final glucose = v.glucoseFasting ?? v.glucosePostMeal ?? v.glucoseRandom;
    if (glucose != null) put(TrendMetric.glucose, TrendPoint(at, glucose.toDouble()));
    if (c.reportsPain) put(TrendMetric.pain, TrendPoint(at, c.painLevel.value.toDouble()));
    if (v.weightKg != null) put(TrendMetric.weight, TrendPoint(at, v.weightKg!));
  }
  for (final g in growth) {
    if (g.weightKg != null) put(TrendMetric.weight, TrendPoint(g.measuredOn, g.weightKg!));
    if (g.heightCm != null) put(TrendMetric.height, TrendPoint(g.measuredOn, g.heightCm!));
  }
  for (final points in out.values) {
    points.sort((a, b) => a.at.compareTo(b.at));
  }
  return {
    for (final m in TrendMetric.values)
      if (out[m] case final p?) m: p
  };
}
