class MintQrResponse {
  const MintQrResponse({required this.tokenId, required this.expiresAt});

  final String tokenId;

  /// Null for permanent tokens (ttl_seconds = 0) — they never expire.
  final DateTime? expiresAt;

  factory MintQrResponse.fromJson(Map<String, dynamic> json) => MintQrResponse(
        tokenId: json['token_id'] as String,
        expiresAt: json['expires_at'] == null ? null : DateTime.parse(json['expires_at'] as String),
      );
}

class ResolveQrResponse {
  const ResolveQrResponse({this.ciphertextBase64, this.preferredLanguage});

  /// Null when the token is expired/revoked (module maps to not-found).
  final String? ciphertextBase64;
  final String? preferredLanguage;

  factory ResolveQrResponse.fromJson(Map<String, dynamic> json) => ResolveQrResponse(
        ciphertextBase64: json['ciphertext'] as String?,
        preferredLanguage: json['preferred_language'] as String?,
      );
}

/// GET /emergency-qr/active — the caller's single active token, if any.
class ActiveQrResponse {
  const ActiveQrResponse({required this.tokenId, required this.expiresAt, required this.ttlSeconds});

  final String tokenId;

  /// Null for permanent tokens.
  final DateTime? expiresAt;
  final int ttlSeconds;

  factory ActiveQrResponse.fromJson(Map<String, dynamic> json) => ActiveQrResponse(
        tokenId: json['token_id'] as String,
        expiresAt: json['expires_at'] == null ? null : DateTime.parse(json['expires_at'] as String),
        ttlSeconds: json['ttl_seconds'] as int,
      );
}
