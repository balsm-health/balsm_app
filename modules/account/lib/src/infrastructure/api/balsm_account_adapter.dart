import 'dart:async';

import 'package:balsm_api/balsm_api.dart';
// AccountSummary + ReadAccountRepository now live in core (cross-module read
// contract); the port + accountSummaryProvider are declared there too.
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Builds the account read-repository from the typed account client. The app
/// composition root binds this into core's `readAccountRepositoryProvider`
/// (see `bootstrap()`), so consumers depend on the core port, not this module.
BalsmAccountAdapter buildAccountAdapter(Ref ref) {
  final adapter = BalsmAccountAdapter(ref.watch(accountApiProvider));
  ref.onDispose(adapter.dispose);
  return adapter;
}
