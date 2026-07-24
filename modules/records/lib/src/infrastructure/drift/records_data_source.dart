import 'dart:async';
import 'dart:convert';

import 'package:core/core.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/aggregates/record_document.dart';
import '../../domain/value_objects/ids.dart';

/// Drift-backed [UserDataSource] for the health-record vault — the first
/// concrete implementation of core's scoped data-source contract.
///
/// Scope semantics (per `ScopedDataSource`):
/// - `scope == null` → the ACTIVE user from the injected [activeUser]
///   callback (bound to `currentUserIdProvider` in the provider below).
/// - no active user → mutations throw [NoActiveUserException]; reads return
///   null/empty; [clear] is an idempotent no-op (logout may run twice).
/// - rows are isolated per partition: every query filters on `user_id`, so
///   one user's records are invisible to another's session.
///
/// Fail-loud: backend failures surface as [StorageWriteException]; a row
/// whose json/enum fields don't decode throws [StorageDecodeException].
class DriftRecordsDataSource extends UserDataSource<RecordDocumentId, RecordDocument>
    implements WatchableScopedDataSource<RecordDocumentId, RecordDocument, UserId> {
  DriftRecordsDataSource(this._db, this.activeUser);

  final AppDatabase _db;

  /// Resolves the active user at call time (null = signed out).
  final UserId? Function() activeUser;

  static const _table = 'health_record';

  /// Change signal for [watch]/[watchAll]. The schema is raw SQL (no
  /// generated TableInfo), so drift's table-based stream invalidation cannot
  /// fire — mutations ping this instead and watchers re-query.
  final _changes = StreamController<void>.broadcast();

  void _notifyChanged() {
    if (!_changes.isClosed) _changes.add(null);
  }

  UserId? _resolve(UserId? scope) => scope ?? activeUser();

  UserId _require(UserId? scope) {
    final user = _resolve(scope);
    if (user == null) throw const NoActiveUserException();
    return user;
  }

  // ── Reads ────────────────────────────────────────────────────────────────

  @override
  Future<RecordDocument?> find(RecordDocumentId key, {UserId? scope}) async {
    final user = _resolve(scope);
    if (user == null) return null;
    final rows = await _db.customSelect(
      'SELECT * FROM $_table WHERE id = ? AND user_id = ? LIMIT 1',
      variables: [Variable<String>(key.value), Variable<String>(user.value)],
    ).get();
    return rows.isEmpty ? null : _fromRow(rows.first.data);
  }

  @override
  Future<List<RecordDocument>> findAll({UserId? scope}) async {
    final user = _resolve(scope);
    if (user == null) return const [];
    final rows = await _db.customSelect(
      'SELECT * FROM $_table WHERE user_id = ? ORDER BY taken_at DESC',
      variables: [Variable<String>(user.value)],
    ).get();
    return rows.map((r) => _fromRow(r.data)).toList();
  }

  @override
  Future<List<RecordDocument>> findMany(Iterable<RecordDocumentId> keys,
      {UserId? scope}) async {
    final user = _resolve(scope);
    if (user == null || keys.isEmpty) return const [];
    final ids = keys.map((k) => k.value).toList();
    final placeholders = List.filled(ids.length, '?').join(', ');
    final rows = await _db.customSelect(
      'SELECT * FROM $_table WHERE user_id = ? AND id IN ($placeholders) '
      'ORDER BY taken_at DESC',
      variables: [
        Variable<String>(user.value),
        ...ids.map((id) => Variable<String>(id)),
      ],
    ).get();
    return rows.map((r) => _fromRow(r.data)).toList();
  }

  @override
  Future<bool> exists(RecordDocumentId key, {UserId? scope}) async =>
      await find(key, scope: scope) != null;

  // ── Watch ────────────────────────────────────────────────────────────────

  @override
  Stream<RecordDocument?> watch(RecordDocumentId key, {UserId? scope}) {
    final user = _resolve(scope);
    if (user == null) return Stream.value(null);
    return Stream<RecordDocument?>.multi((emitter) async {
      emitter.add(await find(key, scope: user));
      emitter.addStream(
        _changes.stream.asyncMap((_) => find(key, scope: user)),
      );
    });
  }

  @override
  Stream<List<RecordDocument>> watchAll({UserId? scope}) {
    final user = _resolve(scope);
    if (user == null) return Stream.value(const []);
    return Stream<List<RecordDocument>>.multi((emitter) async {
      emitter.add(await findAll(scope: user));
      emitter.addStream(
        _changes.stream.asyncMap((_) => findAll(scope: user)),
      );
    });
  }

  // ── Writes ───────────────────────────────────────────────────────────────

  @override
  Future<void> put(RecordDocumentId key, RecordDocument value,
      {UserId? scope}) async {
    final user = _require(scope);
    if (value.userId != user) {
      throw StorageWriteException(
        'record ${key.value}: aggregate userId ${value.userId.value} does not '
        'match the target partition ${user.value}',
      );
    }
    try {
      // health_profile_id: dependants seam — anchor to the user's (self)
      // profile row when it exists; NULL otherwise (convergent backfill on a
      // later open fills it). Queries still filter on user_id until F1.
      await _db.customInsert(
        'INSERT OR REPLACE INTO $_table '
        '(id, user_id, health_profile_id, type, title, tags, source, '
        'file_type, file_path, pages, result_note, taken_at, created_at) '
        'VALUES (?, ?, '
        '(SELECT id FROM health_profile WHERE user_id = ?), '
        '?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        variables: [
          Variable<String>(key.value),
          Variable<String>(user.value),
          Variable<String>(user.value),
          Variable<String>(value.type.name),
          Variable<String>(value.title),
          Variable<String>(jsonEncode(value.tags)),
          Variable<String>(value.source.value),
          Variable<String>(value.fileType),
          Variable<String>(value.filePath),
          Variable<int>(value.pages),
          Variable<String>(value.resultNote),
          Variable<String>(value.takenAt.toIso8601String()),
          Variable<String>(value.createdAt.toIso8601String()),
        ],
      );
    } catch (e) {
      if (e is StorageException) rethrow;
      throw StorageWriteException('record ${key.value}: write failed', e);
    }
    _notifyChanged();
  }

  @override
  Future<void> putBulk(Map<RecordDocumentId, RecordDocument> values,
      {UserId? scope}) async {
    final user = _require(scope);
    await _db.transaction(() async {
      for (final entry in values.entries) {
        await put(entry.key, entry.value, scope: user);
      }
    });
    _notifyChanged();
  }

  @override
  Future<void> delete(RecordDocumentId key, {UserId? scope}) async {
    final user = _require(scope);
    await _db.customUpdate(
      'DELETE FROM $_table WHERE id = ? AND user_id = ?',
      variables: [Variable<String>(key.value), Variable<String>(user.value)],
      updateKind: UpdateKind.delete,
    );
    _notifyChanged();
  }

  @override
  Future<void> deleteMany(Iterable<RecordDocumentId> keys,
      {UserId? scope}) async {
    final user = _require(scope);
    if (keys.isEmpty) return;
    final ids = keys.map((k) => k.value).toList();
    final placeholders = List.filled(ids.length, '?').join(', ');
    await _db.customUpdate(
      'DELETE FROM $_table WHERE user_id = ? AND id IN ($placeholders)',
      variables: [
        Variable<String>(user.value),
        ...ids.map((id) => Variable<String>(id)),
      ],
      updateKind: UpdateKind.delete,
    );
    _notifyChanged();
  }

  @override
  Future<void> clear({UserId? scope}) async {
    final user = _resolve(scope);
    if (user == null) return; // idempotent logout cleanup
    await _db.customUpdate(
      'DELETE FROM $_table WHERE user_id = ?',
      variables: [Variable<String>(user.value)],
      updateKind: UpdateKind.delete,
    );
    _notifyChanged();
  }

  @override
  Future<void> clearAll() async {
    await _db.customUpdate('DELETE FROM $_table',
        updateKind: UpdateKind.delete);
    _notifyChanged();
  }

  // ── Mapping ──────────────────────────────────────────────────────────────

  RecordDocument _fromRow(Map<String, dynamic> row) {
    try {
      return RecordDocument(
        id: RecordDocumentId.value(row['id'] as String),
        userId: UserId.value(row['user_id'] as String),
        type: RecordType.values.byName(row['type'] as String),
        title: row['title'] as String,
        tags: (jsonDecode(row['tags'] as String) as List).cast<String>(),
        source: RecordSource(row['source'] as String),
        fileType: row['file_type'] as String?,
        filePath: row['file_path'] as String?,
        pages: row['pages'] as int?,
        resultNote: row['result_note'] as String?,
        takenAt: DateTime.parse(row['taken_at'] as String),
        createdAt: DateTime.parse(row['created_at'] as String),
      );
    } catch (e) {
      if (e is StorageException) rethrow;
      throw StorageDecodeException(
          'health_record row ${row['id']}: undecodable', e);
    }
  }
}

/// DI: user-partitioned records vault bound to the active user port.
/// The app composition root only needs `appDatabaseProvider` overridden.
final recordsDataSourceProvider = Provider<DriftRecordsDataSource>((ref) {
  return DriftRecordsDataSource(
    ref.watch(appDatabaseProvider),
    () => ref.read(currentUserIdProvider),
  );
});
