/// POST /emergency-qr/mint body. The AES-GCM key is NEVER part of any
/// request — client-side encryption only. Field names match the server's
/// snake_case binding (`MintRequest`): ciphertext, profile_etag, ttl_seconds.
/// Spec v2.0: language travels inside the encrypted payload, so no
/// preferred_language field exists server-side any more.
class MintQrRequest {
  const MintQrRequest({
    required this.ciphertextBase64,
    required this.ttlSeconds,
    required this.profileEtag,
    this.tokenId,
  });

  final String ciphertextBase64;

  /// 0 mints a permanent token (never expires; revoke-only).
  final int ttlSeconds;

  /// Short fingerprint of the encrypted snapshot (max 8 chars server-side),
  /// used to detect when a permanent token's ciphertext is stale.
  final String profileEtag;

  /// Client-generated jti (offline-first mint). Null lets the server assign.
  /// Retrying the same id is idempotent — the server refreshes the ciphertext.
  final String? tokenId;

  Map<String, dynamic> toJson() => {
        'ciphertext': ciphertextBase64,
        'profile_etag': profileEtag,
        'ttl_seconds': ttlSeconds,
        if (tokenId != null) 'token_id': tokenId,
      };
}

/// PUT /emergency-qr/{jti}/ciphertext body — replaces the encrypted snapshot
/// in place so a permanent QR's URL stays stable while showing current data.
class UpdateQrCiphertextRequest {
  const UpdateQrCiphertextRequest({
    required this.ciphertextBase64,
    required this.profileEtag,
  });

  final String ciphertextBase64;
  final String profileEtag;

  Map<String, dynamic> toJson() => {
        'ciphertext': ciphertextBase64,
        'profile_etag': profileEtag,
      };
}
