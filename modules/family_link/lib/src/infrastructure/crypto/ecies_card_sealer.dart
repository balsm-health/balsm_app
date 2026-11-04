import 'dart:convert';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:cryptography/cryptography.dart';

import '../../application/ports/card_sealer.dart';
import '../../application/ports/device_key_store.dart';
import '../../domain/value_objects/emergency_card_payload.dart';
import '../../domain/value_objects/sealed_card.dart';

/// ECIES over X25519 (`dynamic-emergency-share.md`): a fresh ephemeral key pair
/// per seal → X25519 shared secret with the viewer's key → HKDF-SHA256 (info
/// [info], salt = link id) → AES-256-GCM with AAD
/// `linkId|ownerAccountId|version`.
class EciesCardSealer implements CardSealer {
  EciesCardSealer({X25519? x25519, AesGcm? aesGcm})
      : _x25519 = x25519 ?? X25519(),
        _aesGcm = aesGcm ?? AesGcm.with256bits();

  /// HKDF info string — names the purpose and the scheme version.
  static const info = 'balsm-family-card-v1';

  final X25519 _x25519;
  final AesGcm _aesGcm;

  static List<int> aad(String linkId, String ownerAccountId, int version) =>
      utf8.encode('$linkId|$ownerAccountId|$version');

  Future<SecretKey> _key(SecretKey shared, String linkId) => Hkdf(hmac: Hmac.sha256(), outputLength: 32)
      .deriveKey(secretKey: shared, nonce: utf8.encode(linkId), info: utf8.encode(info));

  @override
  Future<SealedCard> seal(
    EmergencyCardPayload card, {
    required Uint8List viewerPublicKey,
    required String linkId,
    required String ownerAccountId,
    required int version,
  }) async {
    final ephemeral = await _x25519.newKeyPair();
    final shared = await _x25519.sharedSecretKey(
      keyPair: ephemeral,
      remotePublicKey: SimplePublicKey(viewerPublicKey, type: KeyPairType.x25519),
    );
    final box = await _aesGcm.encrypt(
      utf8.encode(card.encode()),
      secretKey: await _key(shared, linkId),
      aad: aad(linkId, ownerAccountId, version),
    );
    final epk = await ephemeral.extractPublicKey();
    return SealedCard(
      version: version,
      ephemeralPublicKey: Uint8List.fromList(epk.bytes),
      nonce: Uint8List.fromList(box.nonce),
      ciphertext: Uint8List.fromList([...box.cipherText, ...box.mac.bytes]),
    );
  }

  @override
  Future<AppResult<EmergencyCardPayload>> open(
    SealedCard sealed, {
    required DeviceKeyPair keyPair,
    required String linkId,
    required String ownerAccountId,
  }) async {
    final macLength = _aesGcm.macAlgorithm.macLength;
    if (sealed.ciphertext.length < macLength || sealed.ephemeralPublicKey.length != 32) {
      return AppResult.failure(const ValidationFailure('Corrupt sealed card'));
    }
    try {
      final shared = await _x25519.sharedSecretKey(
        keyPair: SimpleKeyPairData(
          keyPair.privateKey,
          publicKey: SimplePublicKey(keyPair.publicKey, type: KeyPairType.x25519),
          type: KeyPairType.x25519,
        ),
        remotePublicKey: SimplePublicKey(sealed.ephemeralPublicKey, type: KeyPairType.x25519),
      );
      final split = sealed.ciphertext.length - macLength;
      final plain = await _aesGcm.decrypt(
        SecretBox(
          sealed.ciphertext.sublist(0, split),
          nonce: sealed.nonce,
          mac: Mac(sealed.ciphertext.sublist(split)),
        ),
        secretKey: await _key(shared, linkId),
        aad: aad(linkId, ownerAccountId, sealed.version),
      );
      final json = jsonDecode(utf8.decode(plain));
      final card = json is Map<String, dynamic> ? EmergencyCardPayload.tryFromJson(json) : null;
      if (card == null) return AppResult.failure(const ValidationFailure('Unknown card schema'));
      return AppResult.success(card);
    } on SecretBoxAuthenticationError {
      // Wrong key, tampered bytes, or bound to another link/owner/version.
      return AppResult.failure(const ValidationFailure('Card does not open with this key'));
    } on ArgumentError {
      return AppResult.failure(const ValidationFailure('Corrupt sealed card'));
    } on FormatException {
      return AppResult.failure(const ValidationFailure('Corrupt sealed card'));
    }
  }
}
