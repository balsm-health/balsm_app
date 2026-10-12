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

/// Spec v2.0 public envelope. Revoked/expired/unknown tokens never reach
/// this type — the server answers a uniform 404 and the transport layer
/// throws [ApiException] instead.
class ResolveQrResponse {
  const ResolveQrResponse({
    required this.envelopeVersion,
    required this.type,
    required this.expiresAt,
    required this.ciphertextBase64,
  });

  final int envelopeVersion;

  /// "profile" in P001; delegation tokens (P002) introduce new values —
  /// scanning apps route on it.
  final String type;

  /// Null means permanent.
  final DateTime? expiresAt;

  final String ciphertextBase64;

  factory ResolveQrResponse.fromJson(Map<String, dynamic> json) => ResolveQrResponse(
        envelopeVersion: json['v'] as int,
        type: json['type'] as String,
        expiresAt: json['expires_at'] == null ? null : DateTime.parse(json['expires_at'] as String),
        ciphertextBase64: json['ciphertext_base64'] as String,
      );
}

/// One row of the owner's scan history (GET /emergency-qr/scans).
class QrScanEntry {
  const QrScanEntry({
    required this.tokenId,
    required this.resolvedAt,
    required this.client,
    this.country,
  });

  final String tokenId;
  final DateTime resolvedAt;

  /// Coarse scanner class: "web", "app", or "unknown" — never an identity.
  final String client;
  final String? country;

  factory QrScanEntry.fromJson(Map<String, dynamic> json) => QrScanEntry(
        tokenId: json['token_id'] as String,
        resolvedAt: DateTime.parse(json['resolved_at'] as String),
        client: json['client'] as String,
        country: json['country'] as String?,
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
