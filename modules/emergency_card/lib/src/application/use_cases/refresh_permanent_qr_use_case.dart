import 'dart:convert';

import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../emergency_snapshot_reader.dart';
import '../permanent_qr_store.dart';
import 'mint_emergency_qr_token_use_case.dart' show snapshotEtag;

/// Keeps the permanent QR's server-side ciphertext in sync with the on-device
/// medical profile, so a scan always shows current data while the QR URL
/// (jti + key fragment) never changes.
///
/// Idempotent and cheap: no stored permanent QR, or an unchanged snapshot
/// etag, is a no-op. Callers fire-and-forget (sheet open, app start, after a
/// profile save) — failures are surfaced as [AppResult] but never block UI.
///
/// PHI rule: re-encryption happens with the SAME device-held key; only the
/// new ciphertext travels. Nothing here is logged.
class RefreshPermanentQrUseCase {
  RefreshPermanentQrUseCase({
    required EmergencyQrApi api,
    required EmergencySnapshotReader snapshotReader,
    required PermanentQrStore permanentStore,
    AesGcm? aesGcm,
  })  : _api = api,
        _snapshotReader = snapshotReader,
        _permanentStore = permanentStore,
        _aesGcm = aesGcm ?? AesGcm.with256bits();

  final EmergencyQrApi _api;
  final EmergencySnapshotReader _snapshotReader;
  final PermanentQrStore _permanentStore;
  final AesGcm _aesGcm;

  /// Returns the up-to-date record (or null when no permanent QR exists).
  Future<AppResult<PermanentQrRecord?>> call({String preferredLanguage = 'en'}) async {
    final record = await _permanentStore.read();
    if (record == null) return AppResult.success(null);

    final snapshot = await _snapshotReader.readSnapshot();
    if (snapshot == null || !snapshot.hasAnyData) {
      // Profile was emptied; leave the token as-is (revoking is a user act).
      return AppResult.success(record);
    }

    final etag = snapshotEtag(snapshot);
    if (etag == record.etag) return AppResult.success(record);

    // Re-encrypt the fresh snapshot with the SAME key so the QR stays valid.
    final keyBytes = base64Url.decode(base64Url.normalize(record.keyB64Url));
    final secretKey = SecretKey(keyBytes);
    final plaintext = utf8.encode(snapshot.toJsonString());
    final secretBox = await _aesGcm.encrypt(plaintext, secretKey: secretKey);
    final ciphertextBase64 = base64.encode(<int>[
      ...secretBox.nonce,
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ]);

    try {
      await _api.updateCiphertext(
        record.jti,
        UpdateQrCiphertextRequest(
          ciphertextBase64: ciphertextBase64,
          profileEtag: etag,
          preferredLanguage: preferredLanguage,
        ),
      );
    } on ApiException catch (e) {
      if (e.statusCode == 404 || e.statusCode == 409 || e.statusCode == 410) {
        // Token no longer exists/active server-side — drop the stale record.
        await _permanentStore.clear();
        return AppResult.success(null);
      }
      if (e.isUnauthorized) return AppResult.failure(const UnauthorizedFailure());
      // Offline or transient — retry on the next trigger.
      return AppResult.failure(const NetworkFailure('Could not refresh emergency QR'));
    }

    final updated = record.copyWith(etag: etag);
    await _permanentStore.write(updated);
    return AppResult.success(updated);
  }
}

final refreshPermanentQrUseCaseProvider = Provider<RefreshPermanentQrUseCase>((ref) {
  return RefreshPermanentQrUseCase(
    api: ref.watch(emergencyQrApiProvider),
    snapshotReader: ref.watch(emergencySnapshotReaderProvider),
    permanentStore: ref.watch(permanentQrStoreProvider),
  );
});
