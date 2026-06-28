import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/events/session_revoked.dart';

/// Revokes every session via `POST /sessions/revoke-all`.
///
/// On success the server returns `{revoked_count}` and a [SessionRevoked]
/// event is dispatched to signal the global revocation.
class SignOutEverywhereUseCase {
  SignOutEverywhereUseCase(this._dio, this._bus);

  final Dio _dio;
  final EventBus _bus;

  Future<AppResult<int>> call() async {
    try {
      final res =
          await _dio.post<Map<String, dynamic>>('/sessions/revoke-all');
      final body = res.data ?? const {};
      final error = body['error'];
      if (error != null) {
        return AppResult.failure(_messageFailure(error));
      }
      final data = (body['data'] as Map<String, dynamic>?) ?? const {};
      final count = (data['revoked_count'] as num?)?.toInt() ?? 0;

      _bus.publish(
        const SessionRevoked(sessionId: '*', deviceLabel: 'All devices'),
      );

      return AppResult.success(count);
    } on DioException catch (e) {
      return AppResult.failure(_failureFor(e));
    }
  }

  AppFailure _messageFailure(Object error) {
    if (error is Map && error['message'] is String) {
      return ValidationFailure(error['message'] as String);
    }
    return const ValidationFailure('Unable to sign out everywhere.');
  }

  AppFailure _failureFor(DioException e) {
    final code = e.response?.statusCode;
    if (code == 401 || code == 403) return const UnauthorizedFailure();
    return const NetworkFailure();
  }
}

final signOutEverywhereUseCaseProvider =
    Provider<SignOutEverywhereUseCase>((ref) {
  return SignOutEverywhereUseCase(
    ref.watch(dioClientProvider),
    ref.watch(eventBusProvider),
  );
});
