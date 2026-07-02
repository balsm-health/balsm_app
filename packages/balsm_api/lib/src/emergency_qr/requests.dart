/// POST /emergency-qr/mint body. The AES-GCM key is NEVER part of any
/// request — client-side encryption only.
class MintQrRequest {
  const MintQrRequest({required this.ciphertextBase64, required this.ttlSeconds});

  final String ciphertextBase64;
  final int ttlSeconds;

  Map<String, dynamic> toJson() => {
        'ciphertext_base64': ciphertextBase64,
        'ttl_seconds': ttlSeconds,
      };
}

/// POST /emergency-qr/revoke body.
class RevokeQrRequest {
  const RevokeQrRequest({required this.tokenId});

  final String tokenId;

  Map<String, dynamic> toJson() => {'token_id': tokenId};
}
