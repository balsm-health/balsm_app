import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/value_objects/ids.dart';
import '../../domain/events/emergency_qr_token_revoked.dart';
import '../permanent_qr_store.dart';

/// FR: Revoke a previously minted emergency QR token so its public resolve
/// endpoint returns 410 Gone.
class RevokeEmergencyQrTokenUseCase {
  RevokeEmergencyQrTokenUseCase({
    required EmergencyQrApi api,
    required EventBus eventBus,
    required PermanentQrStore permanentStore,
  })  : _api = api,
        _eventBus = eventBus,
        _permanentStore = permanentStore;

  final EmergencyQrApi _api;
  final EventBus _eventBus;
  final PermanentQrStore _permanentStore;

  Future<AppResult<void>> call({required QrTokenId tokenId}) async {
    try {
      await _api.revoke(tokenId.value);
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        return AppResult.failure(const UnauthorizedFailure());
      }
      if (e.statusCode == 404) {
        return AppResult.failure(const NotFoundFailure('Token not found'));
      }
      return AppResult.failure(const NetworkFailure('Could not revoke QR'));
    }

    // A revoked permanent token's stored key is useless — drop the record.
    final stored = await _permanentStore.read();
    if (stored != null && stored.jti == tokenId.value) {
      await _permanentStore.clear();
    }

    _eventBus.publish(EmergencyQrTokenRevoked(jti: tokenId));
    return AppResult.success(null);
  }
}

final revokeEmergencyQrTokenUseCaseProvider = Provider<RevokeEmergencyQrTokenUseCase>((ref) {
  return RevokeEmergencyQrTokenUseCase(
    api: ref.watch(emergencyQrApiProvider),
    eventBus: ref.watch(eventBusProvider),
    permanentStore: ref.watch(permanentQrStoreProvider),
  );
});
