import 'dart:async';

import 'package:balsm_api/balsm_api.dart';
// AccountSummary + ReadAccountRepository now live in core (cross-module read
// contract); the port + accountSummaryProvider are declared there too.
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How long a retained summary is used without asking the server.
///
/// An hour, not a day: the summary changes only when the user changes it, and
/// every mutation path invalidates this cache explicitly through
/// `refreshAccountSummary`. The TTL is the backstop for a change made on
/// another device.
const _accountTtl = Duration(hours: 1);

const _accountNamespace = 'account';

/// .NET REST adapter for the account read-model.
///
/// Anti-corruption layer: maps [AccountSelfResponse] → [AccountSummary].
/// PHI rule: never logs the response body (it may contain user identifiers);
/// only structural failures are surfaced as typed [AppFailure]s upstream.
///
/// Retains the summary so settings, language and country screens render with
/// no connection. The key is whatever id the caller passes — in practice the
/// literal `'self'`, since that is what `accountSummaryProvider` asks for — so
/// account separation rests on the cache being cleared at every session
/// boundary (sign-in, sign-out and expiry all clear it in `bootstrap()`).
class BalsmAccountAdapter implements ReadAccountRepository {
  BalsmAccountAdapter(this._api, this._cache);

  final AccountApi _api;
  final CachedValue<AccountSummary> _cache;

  /// Local fan-out so [watchAccount] re-emits after mutations re-fetch.
  final _controller = StreamController<AccountSummary>.broadcast();

  @override
  Future<AccountSummary?> getAccount(String userId) async {
    final AccountSummary? summary;
    try {
      summary = await _cache.read(userId, fetch: () async {
        final res = await _api.getSelf();
        if (res == null) return null;
        return AccountSummary(
          id: UserId.value(res.id),
          handle: res.handle,
          displayName: res.displayName,
          countryCode: res.countryCode,
          preferredLanguage: res.preferredLanguage,
          deletionState: res.deletionState,
        );
      });
    } catch (e) {
      // A rejected session must not keep serving a cached identity. The
      // interceptor signs out on its own; drop the row first so nothing races
      // a read against the teardown.
      if (_isRejection(e)) await _cache.invalidate(userId);
      rethrow;
    }

    if (summary != null && !_controller.isClosed) _controller.add(summary);
    return summary;
  }

  @override
  Stream<AccountSummary> watchAccount(String userId) async* {
    final current = await getAccount(userId);
    if (current != null) yield current;
    yield* _controller.stream;
  }

  @override
  Future<void> refresh(String userId) => _cache.invalidate(userId);

  void dispose() => _controller.close();

  /// `NetworkManager` converts every dio failure into an [ApiException] before
  /// a caller sees it, so this is the only shape that reaches here.
  static bool _isRejection(Object e) => e is ApiException && e.isUnauthorized;
}

/// Builds the account read-repository from the typed account client. The app
/// composition root binds this into core's `readAccountRepositoryProvider`
/// (see `bootstrap()`), so consumers depend on the core port, not this module.
BalsmAccountAdapter buildAccountAdapter(Ref ref) {
  final adapter = BalsmAccountAdapter(
    ref.watch(accountApiProvider),
    CachedValue<AccountSummary>(
      store: ref.watch(cacheStoreProvider),
      namespace: _accountNamespace,
      ttl: _accountTtl,
      decode: AccountSummary.fromJson,
      encode: (s) => s.toJson(),
    ),
  );
  ref.onDispose(adapter.dispose);
  return adapter;
}
