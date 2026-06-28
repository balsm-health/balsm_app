import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/aggregates/active_session.dart';

/// Lists the current user's active device sessions via `GET /sessions`.
class ListActiveSessionsUseCase {
  ListActiveSessionsUseCase(this._dio);

  final Dio _dio;

  Future<AppResult<List<ActiveSession>>> call() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/sessions');
      final body = res.data ?? const {};
      final error = body['error'];
      if (error != null) {
        return AppResult.failure(_messageFailure(error));
      }
      final list = (body['data'] as List<dynamic>? ?? const [])
          .map((e) => ActiveSession.fromJson(e as Map<String, dynamic>))
          .toList();
      return AppResult.success(list);
    } on DioException catch (e) {
      return AppResult.failure(_failureFor(e));
    }
  }

  AppFailure _messageFailure(Object error) {
    if (error is Map && error['message'] is String) {
      return ValidationFailure(error['message'] as String);
    }
    return const ValidationFailure('Unable to load sessions.');
  }

  AppFailure _failureFor(DioException e) {
    final code = e.response?.statusCode;
    if (code == 401 || code == 403) return const UnauthorizedFailure();
    return const NetworkFailure();
  }
}

final listActiveSessionsUseCaseProvider =
    Provider<ListActiveSessionsUseCase>((ref) {
  return ListActiveSessionsUseCase(ref.watch(dioClientProvider));
});
