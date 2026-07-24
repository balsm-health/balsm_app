import 'package:core/core.dart';

import '../value_objects/body_region.dart';
import '../value_objects/ids.dart';
import '../value_objects/mood.dart';
import '../value_objects/pain_level.dart';
import '../value_objects/symptom.dart';
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
    required this.mood,
    required this.painLevel,
    required this.painRegions,
    required this.symptoms,
    required this.vitals,
    this.note,
    this.photoRecordId,
  });

  final CheckInId id;
  final HealthProfileId healthProfileId;
  final DateTime recordedAt;
  final Mood mood;
  final PainLevel painLevel;
  final Set<BodyRegion> painRegions;
  final Set<SymptomId> symptoms;
  final Vitals vitals;
  final String? note;

  /// Back-reference to a photo in the records vault (never the bytes).
  final String? photoRecordId;
}
