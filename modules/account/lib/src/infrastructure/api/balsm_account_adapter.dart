import 'dart:async';

import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repositories/read_account_repository.dart';
import '../../domain/value_objects/account_summary.dart';

/// .NET REST adapter for the account read-model.
///
/// Anti-corruption layer: maps [AccountSelfResponse] → [AccountSummary].
/// PHI rule: never logs the response body (it may contain user identifiers);
/// only structural failures are surfaced as typed [AppFailure]s upstream.
class BalsmAccountAdapter implements ReadAccountRepository {
  BalsmAccountAdapter(this._api);

  final AccountApi _api;

  /// Local fan-out so [watchAccount] re-emits after mutations re-fetch.
  final _controller = StreamController<AccountSummary>.broadcast();

  @override
  Future<AccountSummary?> getAccount(String userId) async {
    final res = await _api.getSelf();
    if (res == null) return null;
    final summary = AccountSummary(
      id: res.id,
      handle: res.handle,
      displayName: res.displayName,
      countryCode: res.countryCode,
      preferredLanguage: res.preferredLanguage,
      deletionState: res.deletionState,
    );
    if (!_controller.isClosed) _controller.add(summary);
    return summary;
  }

  @override
  Stream<AccountSummary> watchAccount(String userId) async* {
    final current = await getAccount(userId);
    if (current != null) yield current;
    yield* _controller.stream;
  }

  void dispose() => _controller.close();
}

/// DI: the account read-repository backed by the typed account client.
final readAccountRepositoryProvider = Provider<ReadAccountRepository>((ref) {
  final adapter = BalsmAccountAdapter(ref.watch(accountApiProvider));
  ref.onDispose(adapter.dispose);
  return adapter;
});

/// GET /account/self → AccountSummary (null when the account is missing).
final accountSummaryProvider = FutureProvider<AccountSummary?>((ref) async {
  final repo = ref.watch(readAccountRepositoryProvider);
  // 'self' is resolved server-side from the auth token; the id arg is unused
  // by the /account/self endpoint but kept for the repository contract.
  return repo.getAccount('self');
});
