import '../aggregates/auth_session.dart';

/// Read-side repository for observing the current authentication session.
/// Follows the CQRS read-model pattern — no mutations.
abstract interface class ReadAuthRepository {
  /// Stream that emits the current [AuthSession] whenever it changes.
  /// Starts with the current persisted state on subscribe.
  Stream<AuthSession> watchSession();
}
