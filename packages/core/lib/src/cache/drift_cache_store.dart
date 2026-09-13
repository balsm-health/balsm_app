import 'package:drift/drift.dart';

import '../db/app_database.dart';
import 'cache_row.dart';
import 'cache_store.dart';

/// [CacheStore] over the `cache_entry` table in [AppDatabase].
///
/// Raw SQL rather than generated drift tables, matching every other DAO in
/// this database (see the schema consts in `app_database.dart`).
class DriftCacheStore implements CacheStore {
  const DriftCacheStore(this._db);

  final AppDatabase _db;

  @override
  Future<CacheRow?> read(String namespace, String key) async {
    final rows = await _db.customSelect(
      'SELECT key, payload, fetched_at FROM cache_entry WHERE namespace = ? AND key = ? LIMIT 1',
      variables: [Variable.withString(namespace), Variable.withString(key)],
    ).get();
    if (rows.isEmpty) return null;
    return _toRow(rows.first);
  }

  @override
  Future<void> write(String namespace, String key, String payload) => _db.customInsert(
        'INSERT OR REPLACE INTO cache_entry (namespace, key, payload, fetched_at) VALUES (?, ?, ?, ?)',
        variables: [
          Variable.withString(namespace),
          Variable.withString(key),
          Variable.withString(payload),
          Variable.withInt(DateTime.now().toUtc().millisecondsSinceEpoch),
        ],
      );

  @override
  Future<void> delete(String namespace, String key) => _db.customStatement(
        'DELETE FROM cache_entry WHERE namespace = ? AND key = ?',
        [namespace, key],
      );

  @override
  Future<List<CacheRow>> readNamespace(String namespace) async {
    final rows = await _db.customSelect(
      'SELECT key, payload, fetched_at FROM cache_entry WHERE namespace = ? ORDER BY fetched_at DESC',
      variables: [Variable.withString(namespace)],
    ).get();
    return rows.map(_toRow).toList(growable: false);
  }

  @override
  Future<void> evictOldest(String namespace, {required int keep}) => _db.customStatement(
        'DELETE FROM cache_entry WHERE namespace = ? AND key NOT IN ('
        '  SELECT key FROM cache_entry WHERE namespace = ? ORDER BY fetched_at DESC LIMIT ?'
        ')',
        [namespace, namespace, keep],
      );

  @override
  Future<void> clearNamespace(String namespace) =>
      _db.customStatement('DELETE FROM cache_entry WHERE namespace = ?', [namespace]);

  @override
  Future<void> clearAll() => _db.customStatement('DELETE FROM cache_entry');

  CacheRow _toRow(QueryRow r) => CacheRow(
        key: r.read<String>('key'),
        payload: r.read<String>('payload'),
        fetchedAt: DateTime.fromMillisecondsSinceEpoch(r.read<int>('fetched_at'), isUtc: true),
      );
}
