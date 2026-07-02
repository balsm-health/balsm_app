class SessionResponse {
  const SessionResponse({
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

  factory SessionResponse.fromJson(Map<String, dynamic> json) => SessionResponse(
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

class RevokeAllSessionsResponse {
  const RevokeAllSessionsResponse({required this.revokedCount});

  final int revokedCount;

  factory RevokeAllSessionsResponse.fromJson(Map<String, dynamic> json) =>
      RevokeAllSessionsResponse(
        revokedCount: (json['revoked_count'] as num?)?.toInt() ?? 0,
      );
}
