import 'package:core/core.dart';

import '../value_objects/check_in_metric.dart';
import '../value_objects/ids.dart';
import '../value_objects/mood.dart';
import '../value_objects/pain_level.dart';
import '../value_objects/pain_site.dart';
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
    required this.painLevel,
    required this.painSites,
    required this.symptoms,
    required this.vitals,
    this.mood,
    this.symptomDetails = const {},
    this.note,
    this.photoRecordId,
    this.history = EntryHistory.none,
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

  /// Who other than the patient added, edited or shared this check-in, and
  /// the patient's own edits since. Append-only; empty for the patient's own.
  final EntryHistory history;

  /// Nothing left worth keeping: no reading, no symptom, no note. A check-in
  /// the patient has emptied reading by reading is removed, not kept blank.
  bool get isEmpty =>
      mood == null && !reportsPain && symptoms.isEmpty && vitals.isEmpty && (note == null || note!.trim().isEmpty);

  /// This check-in with [history] in place of its own.
  CheckIn withHistory(EntryHistory history) => CheckIn(
        id: id,
        healthProfileId: healthProfileId,
        recordedAt: recordedAt,
        mood: mood,
        painLevel: painLevel,
        painSites: painSites,
        symptoms: symptoms,
        symptomDetails: symptomDetails,
        vitals: vitals,
        note: note,
        photoRecordId: photoRecordId,
        history: history,
      );

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
      history: history,
    );
  }

  /// This check-in with one reading replaced by the patient's edit of it
  /// ([edit] holds the new values, as the one-metric form captured them).
  ///
  /// Only [metric]'s values change; every other reading stays as it was. The
  /// time, note and photo belong to the whole check-in, so they are taken
  /// from [edit] — the form opened on them and saved them back. With
  /// [symptom], only that one symptom is replaced; the marked body sites
  /// follow it only when it is a located symptom.
  CheckIn withReading(CheckInMetric metric, CheckIn edit, {SymptomId? symptom}) {
    final f = edit.vitals;
    final rest = without(metric).vitals;
    final Vitals vitals;
    if (metric == CheckInMetric.bloodPressure) {
      vitals = rest.copyWith(systolic: f.systolic, diastolic: f.diastolic);
    } else if (metric == CheckInMetric.glucose) {
      vitals = rest.copyWith(
        glucoseFasting: f.glucoseFasting,
        glucosePostMeal: f.glucosePostMeal,
        glucoseRandom: f.glucoseRandom,
      );
    } else if (metric == CheckInMetric.spo2) {
      vitals = rest.copyWith(spo2: f.spo2);
    } else if (metric == CheckInMetric.heartRate) {
      vitals = rest.copyWith(heartRate: f.heartRate);
    } else if (metric == CheckInMetric.weight) {
      vitals = rest.copyWith(weightKg: f.weightKg);
    } else if (metric == CheckInMetric.temperature) {
      vitals = rest.copyWith(temperature: f.temperature);
    } else {
      vitals = this.vitals;
    }

    final pain = metric == CheckInMetric.pain;
    final symptomsEdited = metric == CheckInMetric.symptoms;
    var symptoms = this.symptoms;
    var symptomDetails = this.symptomDetails;
    var painSites = this.painSites;
    if (symptomsEdited && symptom != null) {
      symptoms = {...this.symptoms.where((x) => x != symptom), ...edit.symptoms};
      symptomDetails = {
        for (final e in this.symptomDetails.entries)
          if (e.key != symptom) e.key: e.value,
        ...edit.symptomDetails,
      };
      if (symptom.hasLocation || edit.symptoms.any((x) => x.hasLocation)) painSites = edit.painSites;
    } else if (symptomsEdited) {
      symptoms = edit.symptoms;
      symptomDetails = edit.symptomDetails;
      painSites = edit.painSites;
    } else if (pain) {
      painSites = edit.painSites;
    }

    return CheckIn(
      id: id,
      healthProfileId: healthProfileId,
      recordedAt: edit.recordedAt,
      mood: metric == CheckInMetric.mood ? edit.mood : mood,
      painLevel: pain ? edit.painLevel : painLevel,
      painSites: painSites,
      symptoms: symptoms,
      symptomDetails: symptomDetails,
      vitals: vitals,
      note: edit.note,
      photoRecordId: edit.photoRecordId,
    );
  }
}
