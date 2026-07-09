import 'package:core/core.dart';

/// Typed id of a [Medication] aggregate. Minted on-device ([MedicationId.uuid],
/// UUIDv7 with `local-` provenance); server-authoritative values would come via
/// [MedicationId.value].
class MedicationId extends UniqueId {
  const MedicationId.value(super.value) : super.value();
  const MedicationId.empty() : super.empty();
  MedicationId.uuid() : super.uuid('med-');

  static MedicationId? fromString(String? value) =>
      value?.mapNotNull((v) => MedicationId.value(v));
}

/// Typed id of a dose-history event (append-only record).
class DoseEventId extends UniqueId {
  const DoseEventId.value(super.value) : super.value();
  const DoseEventId.empty() : super.empty();
  DoseEventId.uuid() : super.uuid('dose-');

  static DoseEventId? fromString(String? value) =>
      value?.mapNotNull((v) => DoseEventId.value(v));
}
