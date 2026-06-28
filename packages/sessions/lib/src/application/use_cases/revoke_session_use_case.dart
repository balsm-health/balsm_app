import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/events/session_revoked.dart';

/// Revokes a single device session via `DELETE /sessions/{id}`.
///
/// Revocation is one-way; on success a [SessionRevoked] event is dispatched.
class RevokeSessionUseCase {
  RevokeSessionUseCase(this._dio, this._bus);

  final Dio _dio;
  final EventBus _bus;

  Future<AppResult<void>> call({
    required String sessionId,
    required String deviceLabel,
  }) async {
    try {
      final res =
          await _dio.delete<Map<String, dynamic>>('/sessions/$sessionId');
      final error = (res.data ?? const {})['error'];
      if (error != null) {
        return AppResult.failure<void>(_messageFailure(error));
      }
      _bus.publish(
        SessionRevoked(sessionId: sessionId, deviceLabel: deviceLabel),
      );
      return AppResult.success<void>(null);
    } on DioException catch (e) {
      return AppResult.failure<void>(_failureFor(e));
    }
  }

  AppFailure _messageFailure(Object error) {
    if (error is Map && error['message'] is String) {
      return ValidationFailure(error['message'] as String);
    }
    return const ValidationFailure('Unable to revoke session.');
  }

  AppFailure _failureFor(DioException e) {
    final code = e.response?.statusCode;
    if (code == 401 || code == 403) return const UnauthorizedFailure();
    if (code == 404) return const NotFoundFailure('Session not found.');
    return const NetworkFailure();
  }
}

final revokeSessionUseCaseProvider = Provider<RevokeSessionUseCase>((ref) {
  return RevokeSessionUseCase(
    ref.watch(dioClientProvider),
    ref.watch(eventBusProvider),
  );
});
