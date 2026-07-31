import 'package:core/core.dart';

// HealthProfileId moved to core — it is the scope type of ProfileDataSource,
// shared by every PHI store. Re-exported so module-internal imports of
// `ids.dart` keep resolving it.
export 'package:core/core.dart' show HealthProfileId;

/// Typed id of an [Allergy] entity within the health profile.
class AllergyId extends UniqueId {
  const AllergyId.value(super.value) : super.value();
  const AllergyId.empty() : super.empty();
  AllergyId.uuid() : super.uuidv7('alg');

  static AllergyId? fromString(String? value) => value?.mapNotNull((v) => AllergyId.value(v));
}

/// Typed id of a [ChronicCondition] entity within the health profile.
class ChronicConditionId extends UniqueId {
  const ChronicConditionId.value(super.value) : super.value();
  const ChronicConditionId.empty() : super.empty();
  ChronicConditionId.uuid() : super.uuidv7('cond');

  static ChronicConditionId? fromString(String? value) => value?.mapNotNull((v) => ChronicConditionId.value(v));
}

/// Typed id of an [EmergencyContact] entity within the health profile.
class EmergencyContactId extends UniqueId {
  const EmergencyContactId.value(super.value) : super.value();
  const EmergencyContactId.empty() : super.empty();
  EmergencyContactId.uuid() : super.uuidv7('ec');

  static EmergencyContactId? fromString(String? value) => value?.mapNotNull((v) => EmergencyContactId.value(v));
}
