import 'package:core/core.dart';

/// Typed id of a `VaccinationRecord`. Minted on-device
/// ([VaccinationRecordId.uuid], UUIDv7 with `local-` provenance).
class VaccinationRecordId extends UniqueId {
  const VaccinationRecordId.value(super.value) : super.value();
  VaccinationRecordId.uuid() : super.uuidv7('vac');
}
