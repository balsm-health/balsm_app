import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/events/emergency_qr_token_revoked.dart';

/// FR: Revoke a previously minted emergency QR token so its public resolve
/// endpoint returns 410 Gone.
class RevokeEmergencyQrTokenUseCase {
  RevokeEmergencyQrTokenUseCase({
    required EmergencyQrApi api,
    required EventBus eventBus,
  })  : _api = api,
        _eventBus = eventBus;

  final EmergencyQrApi _api;
  final EventBus _eventBus;

  Future<AppResult<void>> call({required String tokenId}) async {
    try {
      await _api.revoke(RevokeQrRequest(tokenId: tokenId));
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        return AppResult.failure(const UnauthorizedFailure());
      }
      if (e.statusCode == 404) {
        return AppResult.failure(const NotFoundFailure('Token not found'));
      }
      return AppResult.failure(const NetworkFailure('Could not revoke QR'));
    }

    _eventBus.publish(EmergencyQrTokenRevoked(jti: tokenId));
    return AppResult.success(null);
  }
}

final revokeEmergencyQrTokenUseCaseProvider =
    Provider<RevokeEmergencyQrTokenUseCase>((ref) {
  return RevokeEmergencyQrTokenUseCase(
    api: ref.watch(emergencyQrApiProvider),
    eventBus: ref.watch(eventBusProvider),
  );
});
