import 'package:core/core.dart';

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
}
