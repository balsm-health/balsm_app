import '../value_objects/ids.dart';

/// Represents a minted emergency QR token stored locally on the device.
/// The QR URL is: https://app.balsm.health/emergency/{jti}#k={base64url_key}
/// The fragment key is NEVER sent to the server — client-side decryption only.
class EmergencyQrToken {
  const EmergencyQrToken({
    required this.jti,
    required this.expiresAt,
    required this.ttlSeconds,
    this.revokedAt,
  });

  /// Token ID returned by the server's mint endpoint.
  final QrTokenId jti;

  final DateTime expiresAt;

  final DateTime? revokedAt;

  final int ttlSeconds;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  bool get isRevoked => revokedAt != null;

  bool get isActive => !isExpired && !isRevoked;

  EmergencyQrToken copyWith({
    QrTokenId? jti,
    DateTime? expiresAt,
    DateTime? revokedAt,
    int? ttlSeconds,
  }) =>
      EmergencyQrToken(
        jti: jti ?? this.jti,
        expiresAt: expiresAt ?? this.expiresAt,
        revokedAt: revokedAt ?? this.revokedAt,
        ttlSeconds: ttlSeconds ?? this.ttlSeconds,
      );

  Map<String, dynamic> toJson() => {
        'jti': jti.value,
        'expiresAt': expiresAt.toUtc().toIso8601String(),
        'revokedAt': revokedAt?.toUtc().toIso8601String(),
        'ttlSeconds': ttlSeconds,
      };

  factory EmergencyQrToken.fromJson(Map<String, dynamic> json) =>
      EmergencyQrToken(
        jti: QrTokenId.value(json['jti'] as String),
        expiresAt: DateTime.parse(json['expiresAt'] as String),
        revokedAt: json['revokedAt'] == null
            ? null
            : DateTime.parse(json['revokedAt'] as String),
        ttlSeconds: json['ttlSeconds'] as int,
      );
}
