/// Body of `POST /api/v1/family-links`: ask the owner of a scanned profile QR
/// to link accounts. [id] is minted by the client, so a retried request is the
/// same request (the server answers `200` for a replayed id).
///
/// [publicKey] is the requester's device X25519 public key (base64), which the
/// recipient seals their emergency card for if they choose to share it.
class CreateFamilyLinkRequest {
  const CreateFamilyLinkRequest({
    required this.id,
    required this.jti,
    required this.relation,
    required this.publicKey,
  });

  final String id;
  final String jti;
  final String relation;
  final String publicKey;

  Map<String, dynamic> toJson() => {
        'id': id,
        'jti': jti,
        'relation': relation,
        'public_key': publicKey,
      };
}

/// Body of `POST /api/v1/family-links/{id}/approve` and of
/// `PUT /api/v1/family-links/{id}/keys`: the caller's device X25519 public
/// key (base64).
class FamilyLinkKeyRequest {
  const FamilyLinkKeyRequest({required this.publicKey});

  final String publicKey;

  Map<String, dynamic> toJson() => {'public_key': publicKey};
}

/// Body of `PUT /api/v1/family-links/{id}/card`: an emergency card sealed for
/// the other party's device key. Every field is opaque to the server; the
/// byte fields are base64. [version] only ever grows — the server refuses an
/// older one (`409`).
class PutSealedCardRequest {
  const PutSealedCardRequest({
    required this.version,
    required this.ephemeralPublicKey,
    required this.nonce,
    required this.ciphertext,
  });

  final int version;
  final String ephemeralPublicKey;
  final String nonce;
  final String ciphertext;

  Map<String, dynamic> toJson() => {
        'version': version,
        'ephemeral_public_key': ephemeralPublicKey,
        'nonce': nonce,
        'ciphertext': ciphertext,
      };
}
