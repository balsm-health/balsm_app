import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/aggregates/deletion_request.dart';
import '../../domain/events/deletion_events.dart';

/// Cancels a pending account deletion via `POST /deletion/cancel`.
///
/// On success the server returns `{deletion_state}` and a [DeletionCancelled]
/// event is dispatched. Cancellation is only valid while the account is still
/// within the grace window (server-enforced; FSM-guarded client-side too).
class CancelDeletionUseCase {
  CancelDeletionUseCase(this._api, this._bus);

  final DeletionApi _api;
  final EventBus _bus;

  Future<AppResult<DeletionState>> call() async {
    try {
      final res = await _api.cancel();
      final state = _parseState(res.deletionState);

      _bus.publish(const DeletionCancelled());

      return AppResult.success(state);
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
          e.serverMessage ?? 'Unable to cancel account deletion.');
    }
    if (e.isUnauthorized) return const UnauthorizedFailure();
    if (e.statusCode == 409) {
      return const ConflictFailure('Deletion can no longer be cancelled.');
    }
    return const NetworkFailure();
  }
}

final cancelDeletionUseCaseProvider = Provider<CancelDeletionUseCase>((ref) {
  return CancelDeletionUseCase(
    ref.watch(deletionApiProvider),
    ref.watch(eventBusProvider),
  );
});
