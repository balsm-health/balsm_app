import 'dart:convert';

import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/data.dart';
import 'package:uuid/rng.dart';
import 'package:uuid/uuid.dart';

import '../../domain/aggregates/emergency_card_snapshot.dart';
import '../../domain/aggregates/emergency_qr_token.dart';
import '../../domain/value_objects/ids.dart';
import '../../domain/events/emergency_qr_token_minted.dart';
import '../emergency_snapshot_reader.dart';
import '../permanent_qr_store.dart';

/// Result of a successful mint: the token record plus the full QR URL that
/// embeds the AES key in the URL fragment (`#k=`). The fragment is NEVER sent
/// to the server — decryption is client-only.
typedef MintResult = ({EmergencyQrToken token, String qrUrl});

/// ttl_seconds value that mints a permanent (never-expiring) QR.
const int kPermanentQrTtlSeconds = 0;

/// Short fingerprint of a snapshot, sent as `profile_etag` (server caps it at
/// 8 chars) so a permanent token's ciphertext can be recognised as stale.
String snapshotEtag(EmergencyCardSnapshot snapshot) {
  final digest = sha256Sync(utf8.encode(snapshot.toJsonString()));
  return digest.sublist(0, 4).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

List<int> sha256Sync(List<int> bytes) {
  // package:cryptography's Sha256 is async-first; DartSha256 hashSync avoids
  // an await in a pure function.
  final sink = const DartSha256().newHashSink();
  sink.add(bytes);
  sink.close();
  return sink.hashSync().bytes;
}

/// FR: Mint an emergency QR token.
///
/// Flow:
/// 1. Read the on-device HealthProfile snapshot (PHI).
/// 2. Generate an ephemeral 32-byte AES-256-GCM key.
/// 3. Encrypt the snapshot JSON; send only the ciphertext to the mint endpoint.
/// 4. Build the QR URL with the key in the URL fragment.
/// 5. For a permanent mint (ttl 0): persist {jti, key, etag} in the keystore so
///    the same QR can be re-displayed forever and its ciphertext refreshed in
///    place when the profile changes.
/// 6. Dispatch [EmergencyQrTokenMinted].
///
/// PHI (the snapshot, plaintext, and the key) is never logged or sent to Sentry.
class MintEmergencyQrTokenUseCase {
  MintEmergencyQrTokenUseCase({
    required EmergencyQrApi api,
    required EmergencySnapshotReader snapshotReader,
    required EventBus eventBus,
    required PermanentQrStore permanentStore,
    AesGcm? aesGcm,
  })  : _api = api,
        _snapshotReader = snapshotReader,
        _eventBus = eventBus,
        _permanentStore = permanentStore,
        _aesGcm = aesGcm ?? AesGcm.with256bits();

  final EmergencyQrApi _api;
  final EmergencySnapshotReader _snapshotReader;
  final EventBus _eventBus;
  final PermanentQrStore _permanentStore;
  final AesGcm _aesGcm;

  static const _qrBaseUrl = 'https://app.balsm.health/emergency';

  Future<AppResult<MintResult>> call({
    required int ttlSeconds,
    String preferredLanguage = 'en',
  }) async {
    // The QR is a stable profile identity token (booking, emergency,
    // delegations bind to its jti) — an empty medical profile still mints; the
    // payload simply carries no entries yet and fills in via refresh later.
    final snapshot = await _snapshotReader.readSnapshot() ?? EmergencyCardSnapshot(createdAt: DateTime.now());

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
    final etag = snapshotEtag(snapshot);
    final keyB64Url = base64Url.encode(keyBytes).replaceAll('=', '');

    // 3. Permanent mint is OFFLINE-FIRST: the jti is generated on-device
    //    (CSPRNG UUIDv4 — never v7, the resolve surface is public and the id
    //    must carry no structure), the QR works immediately, and the server
    //    learns about the token when the sync lands (mint is idempotent for a
    //    client-supplied token_id). Temporary tokens still mint online — their
    //    expiry is server-enforced and useless without a resolvable row.
    if (ttlSeconds == kPermanentQrTtlSeconds) {
      final jti = QrTokenId.value(const Uuid().v4(config: V4Options(null, CryptoRNG())));
      final qrUrl = '$_qrBaseUrl/${jti.value}#k=$keyB64Url';

      var synced = false;
      try {
        await _api.mint(MintQrRequest(
          ciphertextBase64: ciphertextBase64,
          ttlSeconds: ttlSeconds,
          profileEtag: etag,
          preferredLanguage: preferredLanguage,
          tokenId: jti.value,
        ));
        synced = true;
      } on ApiException {
        // Offline or transient — the QR is already usable; the refresh use
        // case retries the sync (app start + sheet open).
      }

      await _permanentStore.write(PermanentQrRecord(
        jti: jti.value,
        keyB64Url: keyB64Url,
        etag: etag,
        qrUrl: qrUrl,
        synced: synced,
      ));

      final token = EmergencyQrToken(jti: jti, expiresAt: null, ttlSeconds: ttlSeconds);
      _eventBus.publish(EmergencyQrTokenMinted(jti: jti, expiresAt: null));
      return AppResult.success((token: token, qrUrl: qrUrl));
    }

    // Temporary: POST ciphertext only — key never leaves the device.
    final MintQrResponse minted;
    try {
      minted = await _api.mint(MintQrRequest(
        ciphertextBase64: ciphertextBase64,
        ttlSeconds: ttlSeconds,
        profileEtag: etag,
        preferredLanguage: preferredLanguage,
      ));
    } on ApiException catch (e) {
      return AppResult.failure(_mapApiError(e));
    } on TypeError {
      // Missing token_id in an otherwise-successful response.
      return AppResult.failure(const NetworkFailure('Malformed mint response'));
    }

    final jti = QrTokenId.value(minted.tokenId);
    final expiresAt = minted.expiresAt;

    final token = EmergencyQrToken(
      jti: jti,
      expiresAt: expiresAt,
      ttlSeconds: ttlSeconds,
    );
    final qrUrl = '$_qrBaseUrl/${jti.value}#k=$keyB64Url';

    // Minting a temporary token revokes the permanent one server-side —
    // its stored key is now useless.
    await _permanentStore.clear();

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

final mintEmergencyQrTokenUseCaseProvider = Provider<MintEmergencyQrTokenUseCase>((ref) {
  return MintEmergencyQrTokenUseCase(
    api: ref.watch(emergencyQrApiProvider),
    snapshotReader: ref.watch(emergencySnapshotReaderProvider),
    eventBus: ref.watch(eventBusProvider),
    permanentStore: ref.watch(permanentQrStoreProvider),
  );
});
