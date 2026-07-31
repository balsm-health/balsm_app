import 'package:core/core.dart';

/// Typed id of a [Medication] aggregate. Minted on-device ([MedicationId.uuid],
/// UUIDv7 with `local-` provenance); server-authoritative values would come via
/// [MedicationId.value].
class MedicationId extends UniqueId {
  const MedicationId.value(super.value) : super.value();
  const MedicationId.empty() : super.empty();
  MedicationId.uuid() : super.uuidv7('med');

  const MedicationId._(String value, {bool isLocal = false, String prefix = '', String type = UniqueId.key_uuid_v7})
      : super.value(value, isLocal: isLocal, prefix: prefix, type: type);

  /// Rebuilds the typed id — with its provenance — from the navigation JSON
  /// (the `storeKey()` a route param carries).
  factory MedicationId.fromJson(Map<String, dynamic> json) {
    final id = UniqueId.fromJson(json);
    return MedicationId._(id.value, isLocal: id.isLocal, prefix: id.prefix, type: id.type);
  }

  static MedicationId? fromString(String? value) => value?.mapNotNull((v) => MedicationId.value(v));
}

/// Typed id of a dose-history event (append-only record).
class DoseEventId extends UniqueId {
  const DoseEventId.value(super.value) : super.value();
  const DoseEventId.empty() : super.empty();
  DoseEventId.uuid() : super.uuidv7('dose');

  static DoseEventId? fromString(String? value) => value?.mapNotNull((v) => DoseEventId.value(v));
}
