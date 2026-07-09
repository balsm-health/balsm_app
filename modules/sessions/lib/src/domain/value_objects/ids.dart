import 'package:core/core.dart';

/// Typed id of a device session (opaque server-issued id).
/// `SessionId.value('*')` is the sign-out-everywhere sentinel.
class SessionId extends UniqueId {
  const SessionId.value(super.value) : super.value();
  const SessionId.empty() : super.empty();

  static SessionId? fromString(String? value) =>
      value?.mapNotNull((v) => SessionId.value(v));
}

/// Typed id of a device (minted on-device at first sign-in, then stable).
class DeviceId extends UniqueId {
  const DeviceId.value(super.value) : super.value();
  const DeviceId.empty() : super.empty();

  static DeviceId? fromString(String? value) =>
      value?.mapNotNull((v) => DeviceId.value(v));
}
