/// When a glucose reading was taken. Fasting, post-meal and random readings have
/// different healthy ranges, so a value is never judged without its context.
enum GlucoseContext { fasting, postMeal, random }

/// Plausibility bounds and "elevated" cut-offs for self-reported vitals.
///
/// **Plausibility bounds** reject a mistyped digit, not a diagnosis: they sit
/// wide enough that every real reading (including very sick patients and
/// infants) passes, and narrow enough that `20/20` or `999` does not. Units: BP
/// mmHg, heart rate bpm, SpO₂ %, glucose mg/dL, weight kg.
///
/// **Elevated cut-offs** only drive a highlight in the journal ("worth a
/// look"); the app is a journal, not a symptom checker, and gives no advice. They
/// follow common adult guidance (ESC/ISH high-normal BP; ADA glucose
/// thresholds) and are the numbers a clinical reviewer should confirm.
abstract final class VitalLimits {
  static const systolicMin = 60;
  static const systolicMax = 260;
  static const diastolicMin = 30;
  static const diastolicMax = 160;
  static const heartRateMin = 30;
  static const heartRateMax = 220;
  static const spo2Min = 50;
  static const spo2Max = 100;
  static const glucoseMin = 20;
  static const glucoseMax = 600;

  /// Down to a premature newborn; up to the heaviest recorded patients.
  static const weightKgMin = 0.5;
  static const weightKgMax = 500.0;

  /// A blood pressure pair is plausible when each number is in range and the
  /// systolic is above the diastolic (the reverse is a swapped entry).
  static bool bloodPressureOk(int? systolic, int? diastolic) =>
      systolic != null &&
      diastolic != null &&
      systolic >= systolicMin &&
      systolic <= systolicMax &&
      diastolic >= diastolicMin &&
      diastolic <= diastolicMax &&
      systolic > diastolic;

  static bool heartRateOk(int? bpm) => bpm != null && bpm >= heartRateMin && bpm <= heartRateMax;

  static bool spo2Ok(int? percent) => percent != null && percent >= spo2Min && percent <= spo2Max;

  static bool glucoseOk(int? mgDl) => mgDl != null && mgDl >= glucoseMin && mgDl <= glucoseMax;

  static bool weightKgOk(double? kg) => kg != null && kg >= weightKgMin && kg <= weightKgMax;

  /// High-normal or above: 130 or more systolic, or 85 or more diastolic.
  static bool bloodPressureElevated(int systolic, int diastolic) => systolic >= 130 || diastolic >= 85;

  /// Above the healthy range for how the reading was taken: fasting 100 or more,
  /// 2 h after a meal 140 or more, random 200 or more.
  static bool glucoseElevated(int mgDl, GlucoseContext context) => switch (context) {
        GlucoseContext.fasting => mgDl >= 100,
        GlucoseContext.postMeal => mgDl >= 140,
        GlucoseContext.random => mgDl >= 200,
      };
}
