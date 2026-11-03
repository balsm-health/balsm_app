import 'package:core/core.dart';

// HealthProfileId moved to core — it is the scope type of ProfileDataSource,
// shared by every PHI store. MemberGroupId too — the family module owns the
// groups a member is filed under. Re-exported so module-internal imports of
// `ids.dart` keep resolving them.
export 'package:core/core.dart' show HealthProfileId, MemberGroupId;

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

/// Typed id of a [CareProvider] — a member of the patient's care team.
class CareProviderId extends UniqueId {
  const CareProviderId.value(super.value) : super.value();
  const CareProviderId.empty() : super.empty();
  CareProviderId.uuid() : super.uuidv7('cp');

  static CareProviderId? fromString(String? value) => value?.mapNotNull((v) => CareProviderId.value(v));
}

/// Typed id of the pregnancy a prenatal (baby) profile belongs to.
class PregnancyId extends UniqueId {
  const PregnancyId.value(super.value) : super.value();
  const PregnancyId.empty() : super.empty();
  PregnancyId.uuid() : super.uuidv7('preg');

  static PregnancyId? fromString(String? value) => value?.mapNotNull((v) => PregnancyId.value(v));
}
