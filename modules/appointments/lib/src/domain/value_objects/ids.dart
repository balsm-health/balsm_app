import 'package:core/core.dart';

/// Typed id of an [Appointment]. Minted on-device
/// ([AppointmentId.uuid], UUIDv7 with `local-` provenance).
class AppointmentId extends UniqueId {
  const AppointmentId.value(super.value) : super.value();
  const AppointmentId.empty() : super.empty();
  AppointmentId.uuid() : super.uuidv7('apt');

  static AppointmentId? fromString(String? value) => value?.mapNotNull((v) => AppointmentId.value(v));
}
