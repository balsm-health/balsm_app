import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/aggregates/deletion_request.dart';
import '../../domain/events/deletion_events.dart';

/// Result of a successful deletion intake.
class DeletionIntakeResult {
  const DeletionIntakeResult({required this.graceUntil, required this.state});

  final DateTime graceUntil;
  final DeletionState state;
}

/// Requests account deletion via `POST /deletion/intake`.
///
/// On success the server returns `{grace_until, deletion_state}`; the grace
/// deadline is surfaced to the UI and a [DeletionRequested] event is dispatched.
class RequestDeletionUseCase {
  RequestDeletionUseCase(this._dio, this._bus);

  final Dio _dio;
  final EventBus _bus;

  Future<AppResult<DeletionIntakeResult>> call() async {
    try {
      final res = await _dio.post<Map<String, dynamic>>('/deletion/intake');
      final body = res.data ?? const {};
      final error = body['error'];
      if (error != null) {
        return AppResult.failure(ValidationFailure(_messageFor(error)));
      }
      final data = (body['data'] as Map<String, dynamic>?) ?? const {};
      final graceUntil = DateTime.parse(data['grace_until'] as String).toUtc();
      final state = _parseState(data['deletion_state'] as String?);

      _bus.publish(DeletionRequested(graceUntil: graceUntil));

      return AppResult.success(
        DeletionIntakeResult(graceUntil: graceUntil, state: state),
      );
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
    return 'Unable to request account deletion.';
  }

  AppFailure _failureFor(DioException e) {
    final code = e.response?.statusCode;
    if (code == 401 || code == 403) return const UnauthorizedFailure();
    if (code == 409) return const ConflictFailure();
    return const NetworkFailure();
  }
}

final requestDeletionUseCaseProvider = Provider<RequestDeletionUseCase>((ref) {
  return RequestDeletionUseCase(
    ref.watch(dioClientProvider),
    ref.watch(eventBusProvider),
  );
});
