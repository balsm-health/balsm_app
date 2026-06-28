import 'dart:convert';

import 'package:core/core.dart';
import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
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
    required Dio dio,
    AesGcm? aesGcm,
  })  : _dio = dio,
        _aesGcm = aesGcm ?? AesGcm.with256bits();

  final Dio _dio;
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

    final Response<dynamic> response;
    try {
      response = await _dio.get<dynamic>('/emergency-qr/resolve/$tokenId');
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 404 || status == 410) {
        return AppResult.failure(
          const NotFoundFailure('QR expired or revoked'),
        );
      }
      return AppResult.failure(const NetworkFailure('Could not resolve QR'));
    }

    final envelope = response.data as Map<String, dynamic>?;
    final data = envelope?['data'] as Map<String, dynamic>?;
    final ciphertextBase64 = data?['ciphertext_base64'] as String?;
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
  return ResolveEmergencyQrTokenUseCase(dio: ref.watch(dioClientProvider));
});
