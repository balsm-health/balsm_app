import 'package:core/core.dart';

/// Typed id of a `GrowthEntry`. Minted on-device ([GrowthEntryId.uuid],
/// UUIDv7 with `local-` provenance).
class GrowthEntryId extends UniqueId {
  const GrowthEntryId.value(super.value) : super.value();
  GrowthEntryId.uuid() : super.uuidv7('grw');
}
