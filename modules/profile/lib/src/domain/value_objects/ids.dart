import 'package:core/core.dart';

/// Typed id of the [HealthProfile] aggregate (one per user, on-device PHI).
class HealthProfileId extends UniqueId {
  const HealthProfileId.value(super.value) : super.value();
  const HealthProfileId.empty() : super.empty();
  HealthProfileId.uuid() : super.uuid('hp-');

  static HealthProfileId? fromString(String? value) =>
      value?.mapNotNull((v) => HealthProfileId.value(v));
}

/// Typed id of an [Allergy] entity within the health profile.
class AllergyId extends UniqueId {
  const AllergyId.value(super.value) : super.value();
  const AllergyId.empty() : super.empty();
  AllergyId.uuid() : super.uuid('alg-');

  static AllergyId? fromString(String? value) =>
      value?.mapNotNull((v) => AllergyId.value(v));
}

/// Typed id of a [ChronicCondition] entity within the health profile.
class ChronicConditionId extends UniqueId {
  const ChronicConditionId.value(super.value) : super.value();
  const ChronicConditionId.empty() : super.empty();
  ChronicConditionId.uuid() : super.uuid('cond-');

  static ChronicConditionId? fromString(String? value) =>
      value?.mapNotNull((v) => ChronicConditionId.value(v));
}

/// Typed id of an [EmergencyContact] entity within the health profile.
class EmergencyContactId extends UniqueId {
  const EmergencyContactId.value(super.value) : super.value();
  const EmergencyContactId.empty() : super.empty();
  EmergencyContactId.uuid() : super.uuid('ec-');

  static EmergencyContactId? fromString(String? value) =>
      value?.mapNotNull((v) => EmergencyContactId.value(v));
}
