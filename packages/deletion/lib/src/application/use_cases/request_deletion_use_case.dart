import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
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
  RequestDeletionUseCase(this._api, this._bus);

  final DeletionApi _api;
  final EventBus _bus;

  Future<AppResult<DeletionIntakeResult>> call() async {
    try {
      final res = await _api.requestIntake();
      final state = _parseState(res.deletionState);

      _bus.publish(DeletionRequested(graceUntil: res.graceUntil));

      return AppResult.success(
        DeletionIntakeResult(graceUntil: res.graceUntil, state: state),
      );
    } on ApiException catch (e) {
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

  AppFailure _failureFor(ApiException e) {
    if (e.fromEnvelope) {
      return ValidationFailure(
          e.serverMessage ?? 'Unable to request account deletion.');
    }
    if (e.isUnauthorized) return const UnauthorizedFailure();
    if (e.statusCode == 409) return const ConflictFailure();
    return const NetworkFailure();
  }
}

final requestDeletionUseCaseProvider = Provider<RequestDeletionUseCase>((ref) {
  return RequestDeletionUseCase(
    ref.watch(deletionApiProvider),
    ref.watch(eventBusProvider),
  );
});
