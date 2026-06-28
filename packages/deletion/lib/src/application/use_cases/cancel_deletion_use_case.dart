import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/aggregates/deletion_request.dart';
import '../../domain/events/deletion_events.dart';

/// Cancels a pending account deletion via `POST /deletion/cancel`.
///
/// On success the server returns `{deletion_state}` and a [DeletionCancelled]
/// event is dispatched. Cancellation is only valid while the account is still
/// within the grace window (server-enforced; FSM-guarded client-side too).
class CancelDeletionUseCase {
  CancelDeletionUseCase(this._dio, this._bus);

  final Dio _dio;
  final EventBus _bus;

  Future<AppResult<DeletionState>> call() async {
    try {
      final res = await _dio.post<Map<String, dynamic>>('/deletion/cancel');
      final body = res.data ?? const {};
      final error = body['error'];
      if (error != null) {
        return AppResult.failure(ValidationFailure(_messageFor(error)));
      }
      final data = (body['data'] as Map<String, dynamic>?) ?? const {};
      final state = _parseState(data['deletion_state'] as String?);

      _bus.publish(const DeletionCancelled());

      return AppResult.success(state);
    } on DioException catch (e) {
      return AppResult.failure(_failureFor(e));
    }
  }

  DeletionState _parseState(String? raw) {
    switch (raw) {
      case 'DELETION_REQUESTED':
        return DeletionState.deletionRequested;
      case 'DELETION_CANCELLED':
        return DeletionState.deletionCancelled;
      default:
        return DeletionState.active;
    }
  }

  String _messageFor(Object error) {
    if (error is Map && error['message'] is String) {
      return error['message'] as String;
    }
    return 'Unable to cancel account deletion.';
  }

  AppFailure _failureFor(DioException e) {
    final code = e.response?.statusCode;
    if (code == 401 || code == 403) return const UnauthorizedFailure();
    if (code == 409) {
      return const ConflictFailure('Deletion can no longer be cancelled.');
    }
    return const NetworkFailure();
  }
}

final cancelDeletionUseCaseProvider = Provider<CancelDeletionUseCase>((ref) {
  return CancelDeletionUseCase(
    ref.watch(dioClientProvider),
    ref.watch(eventBusProvider),
  );
});
