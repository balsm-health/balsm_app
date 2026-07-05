import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'account_summary.dart';
import 'read_account_repository.dart';

/// Cross-module read port for the signed-in user's account.
///
/// Declared here so any module can read the account summary **without importing
/// the account module**. Bound in the app composition root (`bootstrap()`) to
/// the account module's `BalsmAccountAdapter` via `overrideWith`.
final readAccountRepositoryProvider = Provider<ReadAccountRepository>(
  (ref) => throw UnimplementedError(
    'readAccountRepositoryProvider must be overridden in bootstrap()',
  ),
);

/// `GET /account/self` → [AccountSummary] (null when the account is missing).
/// Depends only on the core port, so consumers stay decoupled from account.
final accountSummaryProvider = FutureProvider<AccountSummary?>(
  (ref) => ref.watch(readAccountRepositoryProvider).getAccount('self'),
);
