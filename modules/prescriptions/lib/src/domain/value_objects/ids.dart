import 'package:core/core.dart';

import '../../../prescriptions.dart' show Prescription;

import '../aggregates/prescription.dart' show Prescription;

/// Typed id of a [Prescription]. Minted on-device
/// ([PrescriptionId.uuid], UUIDv7 with `local-` provenance).
class PrescriptionId extends UniqueId {
  const PrescriptionId.value(super.value) : super.value();
  const PrescriptionId.empty() : super.empty();
  PrescriptionId.uuid() : super.uuidv7('rx');

  static PrescriptionId? fromString(String? value) => value.mapNotNull(PrescriptionId.value);
}
