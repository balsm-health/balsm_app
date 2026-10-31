import 'package:core/core.dart';

import '../value_objects/check_in_metric.dart';
import '../value_objects/pain_site.dart';
import '../value_objects/ids.dart';
import '../value_objects/mood.dart';
import '../value_objects/pain_level.dart';
import '../value_objects/symptom.dart';
import '../value_objects/symptom_detail.dart';
import '../value_objects/vitals.dart';

/// A single self-report / check-in — the patient's journal entry for a moment
/// in time. PHI, on-device only.
///
/// The subject is a [HealthProfileId] (the person), not the account, so a
/// guardian's check-ins for a dependant partition cleanly once dependants land.
/// Medication adherence and any attached photo are NOT stored here — adherence
/// is recorded as real dose events via the medications module, and a photo
/// lives in the records vault; [photoRecordId] is only a back-reference.
class CheckIn {
  const CheckIn({
    required this.id,
    required this.healthProfileId,
    required this.recordedAt,
    this.mood,
    required this.painLevel,
    required this.painSites,
    required this.symptoms,
    this.symptomDetails = const {},
    required this.vitals,
    this.note,
    this.photoRecordId,
  });

  final CheckInId id;
  final HealthProfileId healthProfileId;
  final DateTime recordedAt;

  /// Null when the patient did not report a mood — a quick-log entry that
  /// captures a single metric (a blood-pressure reading, say) says nothing
  /// about how they felt, and inventing a score would invent PHI.
  final Mood? mood;
  final PainLevel painLevel;

  /// Whether this entry says anything about pain. A quick log of one metric
  /// (a blood-pressure reading, say) stores [PainLevel.none] because the
  /// column cannot be empty, so a zero with no marked sites means "not asked",
  /// and showing it as 0/10 would invent a report.
  bool get reportsPain => !painLevel.isNone || painSites.isNotEmpty;
  final Set<PainSite> painSites;
  final Set<SymptomId> symptoms;

  /// Extra observations per symptom (`quicklog.jsx` `QuickSymptomDetail`).
  /// Sparse: only symptoms the patient actually detailed appear, and only
  /// [SymptomId.hasDetail] ones ever can.
  final Map<SymptomId, SymptomDetail> symptomDetails;

  final Vitals vitals;
  final String? note;

  /// Back-reference to a photo in the records vault (never the bytes).
  final String? photoRecordId;

  /// Nothing left worth keeping: no reading, no symptom, no note. A check-in
  /// the patient has emptied reading by reading is removed, not kept blank.
  bool get isEmpty =>
      mood == null && !reportsPain && symptoms.isEmpty && vitals.isEmpty && (note == null || note!.trim().isEmpty);

  /// This check-in with one reading removed, as the patient deletes it from
  /// the day screen. Removing pain clears the marked sites with the score;
  /// removing symptoms clears their details.
  CheckIn without(CheckInMetric metric) {
    final v = vitals;
    Vitals vitalsWithout() => Vitals(
          systolic: metric == CheckInMetric.bloodPressure ? null : v.systolic,
          diastolic: metric == CheckInMetric.bloodPressure ? null : v.diastolic,
          heartRate: metric == CheckInMetric.heartRate ? null : v.heartRate,
          temperature: metric == CheckInMetric.temperature ? null : v.temperature,
          weightKg: metric == CheckInMetric.weight ? null : v.weightKg,
          spo2: metric == CheckInMetric.spo2 ? null : v.spo2,
          glucoseFasting: metric == CheckInMetric.glucose ? null : v.glucoseFasting,
          glucosePostMeal: metric == CheckInMetric.glucose ? null : v.glucosePostMeal,
          glucoseRandom: metric == CheckInMetric.glucose ? null : v.glucoseRandom,
        );
    final pain = metric == CheckInMetric.pain;
    final symptomsGone = metric == CheckInMetric.symptoms;
    return CheckIn(
      id: id,
      healthProfileId: healthProfileId,
      recordedAt: recordedAt,
      mood: metric == CheckInMetric.mood ? null : mood,
      painLevel: pain ? PainLevel.none : painLevel,
      painSites: pain ? const {} : painSites,
      symptoms: symptomsGone ? const {} : symptoms,
      symptomDetails: symptomsGone ? const {} : symptomDetails,
      vitals: vitalsWithout(),
      note: note,
      photoRecordId: photoRecordId,
    );
  }
}
