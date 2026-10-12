import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cache_row.dart';

/// Raw keyed payloads, grouped by namespace.
///
/// Deliberately policy-free: no TTL, no typing, no eviction schedule. Those
/// belong to whoever owns the data — see `CachedValue` for the single-value
/// policy and the care directory's local source for the bounded one. It is the
/// same split the core [DataSource] contract makes, for the same reason.
abstract interface class CacheStore {
  Future<CacheRow?> read(String namespace, String key);
  Future<void> write(String namespace, String key, String payload);
  Future<void> delete(String namespace, String key);
  Future<List<CacheRow>> readNamespace(String namespace);

  /// Deletes all but the [keep] most recently fetched rows in [namespace].
  /// Other namespaces are untouched.
  Future<void> evictOldest(String namespace, {required int keep});

  Future<void> clearNamespace(String namespace);
  Future<void> clearAll();
}

final cacheStoreProvider = Provider<CacheStore>(
  (ref) => throw UnimplementedError('cacheStoreProvider must be overridden in bootstrap()'),
);
