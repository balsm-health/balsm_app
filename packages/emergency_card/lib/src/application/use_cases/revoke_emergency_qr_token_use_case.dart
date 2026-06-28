import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/events/emergency_qr_token_revoked.dart';

/// FR: Revoke a previously minted emergency QR token so its public resolve
/// endpoint returns 410 Gone.
class RevokeEmergencyQrTokenUseCase {
  RevokeEmergencyQrTokenUseCase({
    required Dio dio,
    required EventBus eventBus,
  })  : _dio = dio,
        _eventBus = eventBus;

  final Dio _dio;
  final EventBus _eventBus;

  Future<AppResult<void>> call({required String tokenId}) async {
    try {
      await _dio.post<dynamic>(
        '/emergency-qr/revoke',
        data: {'token_id': tokenId},
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        return AppResult.failure(const UnauthorizedFailure());
      }
      if (status == 404) {
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
    dio: ref.watch(dioClientProvider),
    eventBus: ref.watch(eventBusProvider),
  );
});
