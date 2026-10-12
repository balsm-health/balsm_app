import 'dart:convert';

import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../permanent_qr_store.dart';
import '../profile_identity_reader.dart';
import 'mint_emergency_qr_token_use_case.dart' show payloadEtag;

/// Keeps the permanent QR's server-side ciphertext in sync with the current
/// identity payload, so a scan always shows current data while the QR URL
/// (jti + key fragment) never changes.
///
/// Idempotent and cheap: no stored permanent QR, or an unchanged payload
/// etag, is a no-op. Callers fire-and-forget (sheet open, app start, after a
/// profile save) — failures are surfaced as [AppResult] but never block UI.
///
/// This is also the legacy-payload migration path (spec v2.0): a pre-v2.0
/// ciphertext's stored etag never matches the new payload's etag, so every
/// device rewrites its ciphertext to schema v1 on the next trigger.
///
/// PHI rule: re-encryption happens with the SAME device-held key; only the
/// new ciphertext travels. Nothing here is logged.
class RefreshPermanentQrUseCase {
  RefreshPermanentQrUseCase({
    required EmergencyQrApi api,
    required ProfileIdentityReader identityReader,
    required PermanentQrStore permanentStore,
    AesGcm? aesGcm,
  })  : _api = api,
        _identityReader = identityReader,
        _permanentStore = permanentStore,
        _aesGcm = aesGcm ?? AesGcm.with256bits();

  final EmergencyQrApi _api;
  final ProfileIdentityReader _identityReader;
  final PermanentQrStore _permanentStore;
  final AesGcm _aesGcm;

  /// Returns the up-to-date record (or null when no permanent QR exists).
  Future<AppResult<PermanentQrRecord?>> call() async {
    final record = await _permanentStore.read();
    if (record == null) return AppResult.success(null);

    // A payload with null identity fields is valid content — the QR is an
    // identity token first, so clearing the profile propagates to the next
    // scan too.
    final payload = await _identityReader.readIdentity();

    final etag = payloadEtag(payload);
    if (etag == record.etag && record.synced) return AppResult.success(record);

    // Re-encrypt the fresh payload with the SAME key so the QR stays valid.
    final keyBytes = base64Url.decode(base64Url.normalize(record.keyB64Url));
    final secretKey = SecretKey(keyBytes);
    final plaintext = utf8.encode(payload.toJsonString());
    final secretBox = await _aesGcm.encrypt(plaintext, secretKey: secretKey);
    final ciphertextBase64 = base64.encode(<int>[
      ...secretBox.nonce,
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ]);

    try {
      if (!record.synced) {
        // Offline-minted token the server has never seen: the idempotent mint
        // (client-supplied token_id) creates it — or refreshes it if an
        // earlier attempt landed without the ack reaching us.
        await _api.mint(MintQrRequest(
          ciphertextBase64: ciphertextBase64,
          ttlSeconds: 0,
          profileEtag: etag,
          tokenId: record.jti,
        ));
      } else {
        await _api.updateCiphertext(
          record.jti,
          UpdateQrCiphertextRequest(
            ciphertextBase64: ciphertextBase64,
            profileEtag: etag,
          ),
        );
      }
    } on ApiException catch (e) {
      if (record.synced && (e.statusCode == 404 || e.statusCode == 409 || e.statusCode == 410)) {
        // Token no longer exists/active server-side — drop the stale record.
        await _permanentStore.clear();
        return AppResult.success(null);
      }
      if (e.isUnauthorized) return AppResult.failure(const UnauthorizedFailure());
      // Offline or transient — retry on the next trigger.
      return AppResult.failure(const NetworkFailure('Could not refresh emergency QR'));
    }

    final updated = record.copyWith(etag: etag, synced: true);
    await _permanentStore.write(updated);
    return AppResult.success(updated);
  }
}

final refreshPermanentQrUseCaseProvider = Provider<RefreshPermanentQrUseCase>((ref) {
  return RefreshPermanentQrUseCase(
    api: ref.watch(emergencyQrApiProvider),
    identityReader: ref.watch(profileIdentityReaderProvider),
    permanentStore: ref.watch(permanentQrStoreProvider),
  );
});
