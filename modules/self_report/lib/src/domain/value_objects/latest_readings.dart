import '../aggregates/check_in.dart';
import 'mood.dart';
import 'pain_level.dart';

/// The newest value of each reading across a patient's check-ins, each taken
/// from the most recent check-in that logged it. A check-in records only what
/// the patient filled in, so a mood-only check-in must not blank the blood
/// pressure logged an hour earlier. PHI; on-device only.
///
/// Pain 0 is stored the same as "not logged", so [pain] is the newest
/// non-zero score.
class LatestReadings {
  const LatestReadings({this.systolic, this.diastolic, this.glucose, this.spo2, this.mood, this.pain});

  /// [history] is newest first, as the check-in history streams it.
  factory LatestReadings.from(List<CheckIn> history) {
    V? newest<V>(V? Function(CheckIn c) pick) {
      for (final c in history) {
        final v = pick(c);
        if (v != null) return v;
      }
      return null;
    }

    final bp = newest((c) => c.vitals.systolic != null && c.vitals.diastolic != null ? c.vitals : null);
    return LatestReadings(
      systolic: bp?.systolic,
      diastolic: bp?.diastolic,
      glucose: newest((c) => c.vitals.glucoseFasting ?? c.vitals.glucosePostMeal ?? c.vitals.glucoseRandom),
      spo2: newest((c) => c.vitals.spo2),
      mood: newest((c) => c.mood),
      pain: newest((c) => c.painLevel.isNone ? null : c.painLevel),
    );
  }

  final int? systolic;
  final int? diastolic;
  final int? glucose;
  final int? spo2;
  final Mood? mood;
  final PainLevel? pain;
}
