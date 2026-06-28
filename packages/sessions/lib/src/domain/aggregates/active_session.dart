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
  });

  final String id;
  final String deviceId;
  final String deviceLabel;
  final String deviceType;
  final DateTime firstSeenAt;
  final DateTime lastActivityAt;
  final DateTime? revokedAt;
  final bool isCurrent;

  bool get isRevoked => revokedAt != null;

  factory ActiveSession.fromJson(Map<String, dynamic> json) {
    return ActiveSession(
      id: json['id'] as String,
      deviceId: json['device_id'] as String,
      deviceLabel: json['device_label'] as String,
      deviceType: json['device_type'] as String,
      firstSeenAt: DateTime.parse(json['first_seen_at'] as String).toUtc(),
      lastActivityAt:
          DateTime.parse(json['last_activity_at'] as String).toUtc(),
      revokedAt: json['revoked_at'] != null
          ? DateTime.parse(json['revoked_at'] as String).toUtc()
          : null,
      isCurrent: json['is_current'] as bool? ?? false,
    );
  }
}
