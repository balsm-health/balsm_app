import 'dart:convert';

import 'package:balsm_api/balsm_api.dart' show isOfflineError;

import 'cache_store.dart';

/// One typed value per key, refreshed on read, kept when the refresh fails
/// because the device is offline.
///
/// The two failure clauses are the whole point, and they are what a hand-rolled
/// cache gets wrong: falling back on a bare `catch` makes a 500 or a malformed
/// body indistinguishable from being offline, and the caller then serves stale
/// data forever without anything looking broken.
class CachedValue<T> {
  const CachedValue({
    required CacheStore store,
    required String namespace,
    required Duration ttl,
    required T Function(Map<String, dynamic>) decode,
    required Map<String, dynamic> Function(T) encode,
  })  : _store = store,
        _namespace = namespace,
        _ttl = ttl,
        _decode = decode,
        _encode = encode;

  final CacheStore _store;
  final String _namespace;
  final Duration _ttl;
  final T Function(Map<String, dynamic>) _decode;
  final Map<String, dynamic> Function(T) _encode;

  /// Fresh row → returned without touching the network.
  /// Stale or absent → [fetch] runs; its result is retained and returned.
  /// [fetch] throws and `isOfflineError` → the retained row at any age, or a
  /// rethrow when there is nothing retained.
  /// [fetch] throws anything else → rethrow, leaving the retained row alone
  /// rather than serving it.
  Future<T?> read(String key, {required Future<T?> Function() fetch}) async {
    final row = await _store.read(_namespace, key);
    final retained = row == null ? null : _tryDecode(row.payload);

    if (row != null && retained != null && row.isFresh(_ttl)) return retained;

    try {
      final fresh = await fetch();
      if (fresh == null) {
        await _store.delete(_namespace, key);
        return null;
      }
      await _store.write(_namespace, key, jsonEncode(_encode(fresh)));
      return fresh;
    } catch (e) {
      if (retained != null && isOfflineError(e)) return retained;
      rethrow;
    }
  }

  /// The retained value, whatever its age. Never fetches.
  Future<T?> peek(String key) async {
    final row = await _store.read(_namespace, key);
    return row == null ? null : _tryDecode(row.payload);
  }

  Future<void> invalidate(String key) => _store.delete(_namespace, key);

  Future<void> invalidateAll() => _store.clearNamespace(_namespace);

  /// A payload this build can no longer read — a shape change across an app
  /// upgrade, or corruption — is a miss, not an error. Throwing here would make
  /// a schema change brick the screen until the user reinstalled.
  T? _tryDecode(String payload) {
    try {
      return _decode(jsonDecode(payload) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
