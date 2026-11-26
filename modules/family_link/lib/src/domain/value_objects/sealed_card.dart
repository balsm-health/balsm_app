import 'dart:typed_data';

/// An emergency card sealed for one viewer's device key: what the server
/// stores and hands back, and nothing it can read.
///
/// [ciphertext] is the AES-256-GCM output followed by its 16-byte tag.
class SealedCard {
  const SealedCard({
    required this.version,
    required this.ephemeralPublicKey,
    required this.nonce,
    required this.ciphertext,
  });

  /// Only ever grows for a link; bound into the AAD, so a replayed older card
  /// cannot pass for a newer one.
  final int version;
  final Uint8List ephemeralPublicKey;
  final Uint8List nonce;
  final Uint8List ciphertext;
}
