import 'package:core/core.dart';

import '../../../self_report.dart' show CheckIn;

import '../aggregates/check_in.dart' show CheckIn;

/// Typed id of a [CheckIn] aggregate. Minted on-device ([CheckInId.uuid],
/// UUIDv7 with `local-` provenance).
class CheckInId extends UniqueId {
  const CheckInId.value(super.value) : super.value();
  const CheckInId.empty() : super.empty();
  CheckInId.uuid() : super.uuidv7('chk');

  static CheckInId? fromString(String? value) => value.mapNotNull(CheckInId.value);
}
