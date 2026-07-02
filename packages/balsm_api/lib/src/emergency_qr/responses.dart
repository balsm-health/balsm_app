class MintQrResponse {
  const MintQrResponse({required this.tokenId, required this.expiresAt});

  final String tokenId;
  final DateTime expiresAt;

  factory MintQrResponse.fromJson(Map<String, dynamic> json) => MintQrResponse(
        tokenId: json['token_id'] as String,
        expiresAt: DateTime.parse(json['expires_at'] as String),
      );
}

class ResolveQrResponse {
  const ResolveQrResponse({this.ciphertextBase64});

  /// Null when the token is expired/revoked (module maps to not-found).
  final String? ciphertextBase64;

  factory ResolveQrResponse.fromJson(Map<String, dynamic> json) =>
      ResolveQrResponse(ciphertextBase64: json['ciphertext_base64'] as String?);
}
