import 'dart:convert';

import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/aggregates/emergency_card_snapshot.dart';

/// FR: Resolve (decrypt) an emergency QR token for a first responder.
///
/// The token id comes from the URL path; the AES-256-GCM key comes from the URL
/// fragment (`#k=...`) and is supplied by the caller. The fragment is never
/// transmitted to the server — this endpoint is public (no auth) and returns
/// only ciphertext, which is decrypted entirely on the client.
class ResolveEmergencyQrTokenUseCase {
  ResolveEmergencyQrTokenUseCase({
    required EmergencyQrApi api,
    AesGcm? aesGcm,
  })  : _api = api,
        _aesGcm = aesGcm ?? AesGcm.with256bits();

  final EmergencyQrApi _api;
  final AesGcm _aesGcm;

  /// [tokenId] is the path segment; [keyBase64Url] is the `k=` fragment value.
  Future<AppResult<EmergencyCardSnapshot>> call({
    required String tokenId,
    required String keyBase64Url,
  }) async {
    final keyBytes = _decodeKey(keyBase64Url);
    if (keyBytes == null || keyBytes.length != 32) {
      return AppResult.failure(
        const ValidationFailure('Invalid or missing decryption key'),
      );
    }

    final ResolveQrResponse resolved;
    try {
      resolved = await _api.resolve(tokenId);
    } on ApiException catch (e) {
      if (e.statusCode == 404 || e.statusCode == 410) {
        return AppResult.failure(
          const NotFoundFailure('QR expired or revoked'),
        );
      }
      return AppResult.failure(const NetworkFailure('Could not resolve QR'));
    }

    final ciphertextBase64 = resolved.ciphertextBase64;
    if (ciphertextBase64 == null) {
      return AppResult.failure(
        const NotFoundFailure('QR expired or revoked'),
      );
    }

    try {
      final payload = base64.decode(ciphertextBase64);
      // Layout: nonce (12) || cipherText (var) || mac (16).
      const nonceLength = 12;
      final macLength = _aesGcm.macAlgorithm.macLength;
      if (payload.length < nonceLength + macLength) {
        return AppResult.failure(
          const ValidationFailure('Corrupt emergency payload'),
        );
      }
      final nonce = payload.sublist(0, nonceLength);
      final cipherText =
          payload.sublist(nonceLength, payload.length - macLength);
      final mac = Mac(payload.sublist(payload.length - macLength));

      final secretKey = SecretKey(keyBytes);
      final plaintext = await _aesGcm.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: mac),
        secretKey: secretKey,
      );
      final snapshot =
          EmergencyCardSnapshot.fromJsonString(utf8.decode(plaintext));
      return AppResult.success(snapshot);
    } catch (_) {
      // Decryption / auth-tag failure — never surface PHI or raw error detail.
      return AppResult.failure(
        const ValidationFailure('Could not decrypt emergency card'),
      );
    }
  }

  List<int>? _decodeKey(String keyBase64Url) {
    if (keyBase64Url.isEmpty) return null;
    try {
      // Restore base64url padding stripped at mint time.
      final padded = keyBase64Url.padRight(
        (keyBase64Url.length + 3) & ~3,
        '=',
      );
      return base64Url.decode(padded);
    } catch (_) {
      return null;
    }
  }
}

final resolveEmergencyQrTokenUseCaseProvider =
    Provider<ResolveEmergencyQrTokenUseCase>((ref) {
  return ResolveEmergencyQrTokenUseCase(api: ref.watch(emergencyQrApiProvider));
});
