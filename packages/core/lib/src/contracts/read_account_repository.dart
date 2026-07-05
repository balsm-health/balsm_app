import 'account_summary.dart';

/// Read-side port for the signed-in user's account summary.
///
/// Implemented by the infrastructure adapter (`BalsmAccountAdapter`).
abstract interface class ReadAccountRepository {
  /// Fetches the account summary for [userId], or null if not found.
  Future<AccountSummary?> getAccount(String userId);

  /// Emits the account summary for [userId] and any subsequent updates.
  Stream<AccountSummary> watchAccount(String userId);
}
