import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/value_objects/ids.dart';
import '../permanent_qr_store.dart';
import 'mint_emergency_qr_token_use_case.dart';
import 'revoke_emergency_qr_token_use_case.dart';

/// Spec v2.0 rotate: revoke the active permanent token and mint a fresh one
/// (new jti + new key) in one action — for a leaked or photographed QR. Old
/// printed copies stop resolving immediately; the caller shows the new QR.
///
/// Composition of the existing revoke + offline-first idempotent mint. When
/// no permanent QR exists it simply mints one.
class RotatePermanentQrUseCase {
  RotatePermanentQrUseCase({
    required RevokeEmergencyQrTokenUseCase revoke,
    required MintEmergencyQrTokenUseCase mint,
    required PermanentQrStore permanentStore,
  })  : _revoke = revoke,
        _mint = mint,
        _permanentStore = permanentStore;

  final RevokeEmergencyQrTokenUseCase _revoke;
  final MintEmergencyQrTokenUseCase _mint;
  final PermanentQrStore _permanentStore;

  Future<AppResult<MintResult>> call() async {
    final record = await _permanentStore.read();
    if (record != null) {
      final revoked = await _revoke(tokenId: QrTokenId.value(record.jti));
      // A failed revoke (offline) must NOT mint a second live token — the
      // old key would stay valid, defeating the point of rotating.
      if (revoked.isFailure) {
        return AppResult.failure(
          const NetworkFailure('Could not rotate QR — check your connection'),
        );
      }
    }
    return _mint(ttlSeconds: kPermanentQrTtlSeconds);
  }
}

final rotatePermanentQrUseCaseProvider = Provider<RotatePermanentQrUseCase>((ref) {
  return RotatePermanentQrUseCase(
    revoke: ref.watch(revokeEmergencyQrTokenUseCaseProvider),
    mint: ref.watch(mintEmergencyQrTokenUseCaseProvider),
    permanentStore: ref.watch(permanentQrStoreProvider),
  );
});
