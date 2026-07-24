/// A self-reported vitals snapshot taken during a check-in. Every field is
/// nullable — the patient fills only what they measured. PHI; on-device only.
///
/// Units: BP in mmHg, heart rate in bpm, temperature in °C, weight in kg,
/// SpO₂ in %, glucose in mg/dL. Glucose is split by context
/// (fasting / post-meal / random) because those are not interchangeable
/// readings.
class Vitals {
  const Vitals({
    this.systolic,
    this.diastolic,
    this.heartRate,
    this.temperature,
    this.weightKg,
    this.spo2,
    this.glucoseFasting,
    this.glucosePostMeal,
    this.glucoseRandom,
  });

  static const empty = Vitals();

  final int? systolic;
  final int? diastolic;
  final int? heartRate;
  final double? temperature;
  final double? weightKg;
  final int? spo2;
  final int? glucoseFasting;
  final int? glucosePostMeal;
  final int? glucoseRandom;

  bool get isEmpty =>
      systolic == null &&
      diastolic == null &&
      heartRate == null &&
      temperature == null &&
      weightKg == null &&
      spo2 == null &&
      glucoseFasting == null &&
      glucosePostMeal == null &&
      glucoseRandom == null;

  Vitals copyWith({
    int? systolic,
    int? diastolic,
    int? heartRate,
    double? temperature,
    double? weightKg,
    int? spo2,
    int? glucoseFasting,
    int? glucosePostMeal,
    int? glucoseRandom,
  }) =>
      Vitals(
        systolic: systolic ?? this.systolic,
        diastolic: diastolic ?? this.diastolic,
        heartRate: heartRate ?? this.heartRate,
        temperature: temperature ?? this.temperature,
        weightKg: weightKg ?? this.weightKg,
        spo2: spo2 ?? this.spo2,
        glucoseFasting: glucoseFasting ?? this.glucoseFasting,
        glucosePostMeal: glucosePostMeal ?? this.glucosePostMeal,
        glucoseRandom: glucoseRandom ?? this.glucoseRandom,
      );

  Map<String, dynamic> toColumns() => {
        'systolic': systolic,
        'diastolic': diastolic,
        'heart_rate': heartRate,
        'temperature': temperature,
        'weight_kg': weightKg,
        'spo2': spo2,
        'glucose_fasting': glucoseFasting,
        'glucose_post_meal': glucosePostMeal,
        'glucose_random': glucoseRandom,
      };

  factory Vitals.fromRow(Map<String, dynamic> row) => Vitals(
        systolic: row['systolic'] as int?,
        diastolic: row['diastolic'] as int?,
        heartRate: row['heart_rate'] as int?,
        temperature: (row['temperature'] as num?)?.toDouble(),
        weightKg: (row['weight_kg'] as num?)?.toDouble(),
        spo2: row['spo2'] as int?,
        glucoseFasting: row['glucose_fasting'] as int?,
        glucosePostMeal: row['glucose_post_meal'] as int?,
        glucoseRandom: row['glucose_random'] as int?,
      );
}
