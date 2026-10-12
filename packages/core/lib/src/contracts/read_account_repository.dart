import 'account_summary.dart';

/// Read-side port for the signed-in user's account summary.
///
/// Implemented by the infrastructure adapter (`BalsmAccountAdapter`).
abstract interface class ReadAccountRepository {
  /// Fetches the account summary for [userId], or null if not found.
  Future<AccountSummary?> getAccount(String userId);

  /// Emits the account summary for [userId] and any subsequent updates.
  Stream<AccountSummary> watchAccount(String userId);

  /// Drops any retained copy so the next [getAccount] goes to the server.
  ///
  /// Invalidating `accountSummaryProvider` alone is not enough: the provider
  /// re-runs, reads the still-fresh retained row, and the change the user just
  /// made appears not to have happened.
  Future<void> refresh(String userId);
}
