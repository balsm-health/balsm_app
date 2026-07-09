import 'dart:convert';

import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/aggregates/emergency_qr_token.dart';
import '../../domain/value_objects/ids.dart';
import '../../domain/events/emergency_qr_token_minted.dart';
import '../emergency_snapshot_reader.dart';

/// Result of a successful mint: the token record plus the full QR URL that
/// embeds the AES key in the URL fragment (`#k=`). The fragment is NEVER sent
/// to the server — decryption is client-only.
typedef MintResult = ({EmergencyQrToken token, String qrUrl});

/// FR: Mint an emergency QR token.
///
/// Flow:
/// 1. Read the on-device HealthProfile snapshot (PHI).
/// 2. Generate an ephemeral 32-byte AES-256-GCM key.
/// 3. Encrypt the snapshot JSON; send only the ciphertext to the mint endpoint.
/// 4. Build the QR URL with the key in the URL fragment.
/// 5. Dispatch [EmergencyQrTokenMinted].
///
/// PHI (the snapshot, plaintext, and the key) is never logged or sent to Sentry.
class MintEmergencyQrTokenUseCase {
  MintEmergencyQrTokenUseCase({
    required EmergencyQrApi api,
    required EmergencySnapshotReader snapshotReader,
    required EventBus eventBus,
    AesGcm? aesGcm,
  })  : _api = api,
        _snapshotReader = snapshotReader,
        _eventBus = eventBus,
        _aesGcm = aesGcm ?? AesGcm.with256bits();

  final EmergencyQrApi _api;
  final EmergencySnapshotReader _snapshotReader;
  final EventBus _eventBus;
  final AesGcm _aesGcm;

  static const _qrBaseUrl = 'https://app.balsm.health/emergency';

  Future<AppResult<MintResult>> call({required int ttlSeconds}) async {
    final snapshot = await _snapshotReader.readSnapshot();
    if (snapshot == null || !snapshot.hasAnyData) {
      return AppResult.failure(
        const ValidationFailure('No emergency health data to share'),
      );
    }

    // 1. Generate ephemeral AES-256-GCM key (32 bytes).
    final secretKey = await _aesGcm.newSecretKey();
    final keyBytes = await secretKey.extractBytes();

    // 2. Encrypt the snapshot JSON. AES-GCM appends the auth tag to cipherText;
    //    we ship nonce || cipherText || mac so the resolver can rebuild the box.
    final plaintext = utf8.encode(snapshot.toJsonString());
    final secretBox = await _aesGcm.encrypt(plaintext, secretKey: secretKey);
    final payload = <int>[
      ...secretBox.nonce,
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ];
    final ciphertextBase64 = base64.encode(payload);

    // 3. POST ciphertext only — key never leaves the device via the network.
    final MintQrResponse minted;
    try {
      minted = await _api.mint(MintQrRequest(
        ciphertextBase64: ciphertextBase64,
        ttlSeconds: ttlSeconds,
      ));
    } on ApiException catch (e) {
      return AppResult.failure(_mapApiError(e));
    } on TypeError {
      // Missing token_id/expires_at in an otherwise-successful response.
      return AppResult.failure(const NetworkFailure('Malformed mint response'));
    }

    final jti = QrTokenId.value(minted.tokenId);
    final expiresAt = minted.expiresAt;

    final token = EmergencyQrToken(
      jti: jti,
      expiresAt: expiresAt,
      ttlSeconds: ttlSeconds,
    );

    // 4. Build QR URL with key in the fragment (base64url, no padding).
    final keyB64Url = base64Url.encode(keyBytes).replaceAll('=', '');
    final qrUrl = '$_qrBaseUrl/${jti.value}#k=$keyB64Url';

    // 5. Dispatch event (no PHI, no key).
    _eventBus.publish(EmergencyQrTokenMinted(jti: jti, expiresAt: expiresAt));

    return AppResult.success((token: token, qrUrl: qrUrl));
  }

  AppFailure _mapApiError(ApiException e) {
    if (e.isUnauthorized) return const UnauthorizedFailure();
    if (e.statusCode == 422 || e.statusCode == 400) {
      return const ValidationFailure('Invalid mint request');
    }
    return const NetworkFailure('Could not generate emergency QR');
  }
}

final mintEmergencyQrTokenUseCaseProvider =
    Provider<MintEmergencyQrTokenUseCase>((ref) {
  return MintEmergencyQrTokenUseCase(
    api: ref.watch(emergencyQrApiProvider),
    snapshotReader: ref.watch(emergencySnapshotReaderProvider),
    eventBus: ref.watch(eventBusProvider),
  );
});
