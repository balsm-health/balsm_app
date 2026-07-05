/// Lifecycle states for an account deletion request.
///
/// FSM (one-way except cancel-back-to-cancelled):
///   active ──request──▶ deletionRequested ──cancel──▶ deletionCancelled
///   deletionRequested ──(grace elapses, server purge)──▶ wiped (off-device)
enum DeletionState { active, deletionRequested, deletionCancelled }

/// Aggregate root for an account-deletion request.
///
/// State transitions are FSM-guarded: deletion is a one-way action and may
/// only be cancelled while still in [DeletionState.deletionRequested].
class DeletionRequest {
  DeletionRequest({
    required this.userId,
    this.state = DeletionState.active,
    this.graceUntil,
    this.confirmedAt,
  });

  final String userId;
  DeletionState state;
  final DateTime? graceUntil;
  final DateTime? confirmedAt;

  /// Cancel a pending deletion. Only valid from DELETION_REQUESTED.
  void cancel() {
    if (state != DeletionState.deletionRequested) {
      throw StateError('cancel only from DELETION_REQUESTED');
    }
    state = DeletionState.deletionCancelled;
  }
}
