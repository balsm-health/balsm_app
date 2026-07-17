import '../value_objects/ids.dart';

/// An authenticated device session for the current user.
///
/// Revocation is one-way: once [revokedAt] is set the session cannot be
/// reactivated.
class ActiveSession {
  const ActiveSession({
    required this.id,
    required this.deviceId,
    required this.deviceLabel,
    required this.deviceType,
    required this.firstSeenAt,
    required this.lastActivityAt,
    this.revokedAt,
    this.isCurrent = false,
    this.approxLocation,
  });

  final SessionId id;
  final DeviceId deviceId;
  final String deviceLabel;
  final String deviceType;
  final DateTime firstSeenAt;
  final DateTime lastActivityAt;
  final DateTime? revokedAt;
  final bool isCurrent;

  /// G11: coarse, city/region-level location the session was last seen from
  /// (e.g. "Dubai, AE"). Null until the .NET API returns it — never fabricated
  /// on-device. Rendered per row only when present.
  final String? approxLocation;

  bool get isRevoked => revokedAt != null;

  factory ActiveSession.fromJson(Map<String, dynamic> json) {
    return ActiveSession(
      id: SessionId.value(json['id'] as String),
      deviceId: DeviceId.value(json['device_id'] as String),
      deviceLabel: json['device_label'] as String,
      deviceType: json['device_type'] as String,
      firstSeenAt: DateTime.parse(json['first_seen_at'] as String).toUtc(),
      lastActivityAt:
          DateTime.parse(json['last_activity_at'] as String).toUtc(),
      revokedAt: json['revoked_at'] != null
          ? DateTime.parse(json['revoked_at'] as String).toUtc()
          : null,
      isCurrent: json['is_current'] as bool? ?? false,
      approxLocation: json['approx_location'] as String?,
    );
  }
}
