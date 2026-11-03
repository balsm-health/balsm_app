import 'dart:async';
import 'dart:convert';

import 'package:core/core.dart';

import '../../application/ports/records_data_source.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/aggregates/record_document.dart';
import '../../domain/value_objects/ids.dart';

/// Drift-backed [ProfileDataSource] for the health-record vault.
///
/// Scope semantics (per `ScopedDataSource`):
/// - `scope == null` → the ACTIVE health profile from the injected
///   [activeProfile] callback (bound to `currentProfileIdProvider` in the
///   provider below) — the person the records are about.
/// - no active profile → mutations throw [NoActiveProfileException]; reads
///   return null/empty; [clear] is an idempotent no-op (logout may run twice).
/// - rows are isolated per partition: every query filters on
///   `health_profile_id`, so one person's records are invisible while another
///   profile is active — a parent's own vault never mixes with a child's.
///
/// `user_id` still records the owning account (from `RecordDocument.userId`)
/// so account-level operations (re-key, merge, discard) keep working.
///
/// Fail-loud: backend failures surface as [StorageWriteException]; a row
/// whose json/enum fields don't decode throws [StorageDecodeException].
class DriftRecordsDataSource extends ProfileDataSource<RecordDocumentId, RecordDocument> implements RecordsDataSource {
  DriftRecordsDataSource(this._db, this.activeProfile);

  final AppDatabase _db;

  /// Resolves the active health profile at call time (null = signed out, or
  /// the self profile is not ensured yet).
  final HealthProfileId? Function() activeProfile;

  static const _table = 'health_record';

  /// Change signal for [watch]/[watchAll]. The schema is raw SQL (no
  /// generated TableInfo), so drift's table-based stream invalidation cannot
  /// fire — mutations ping this instead and watchers re-query.
  final _changes = StreamController<void>.broadcast();

  void _notifyChanged() {
    if (!_changes.isClosed) _changes.add(null);
  }

  HealthProfileId? _resolve(HealthProfileId? scope) => scope ?? activeProfile();

  HealthProfileId _require(HealthProfileId? scope) {
    final profile = _resolve(scope);
    if (profile == null) throw const NoActiveProfileException();
    return profile;
  }

  // ── Reads ────────────────────────────────────────────────────────────────

  @override
  Future<RecordDocument?> find(RecordDocumentId key, {HealthProfileId? scope}) async {
    final profile = _resolve(scope);
    if (profile == null) return null;
    final rows = await _db.customSelect(
      'SELECT * FROM $_table WHERE id = ? AND health_profile_id = ? LIMIT 1',
      variables: [Variable<String>(key.value), Variable<String>(profile.value)],
    ).get();
    return rows.isEmpty ? null : _fromRow(rows.first.data);
  }

  @override
  Future<List<RecordDocument>> findAll({HealthProfileId? scope}) async {
    final profile = _resolve(scope);
    if (profile == null) return const [];
    final rows = await _db.customSelect(
      'SELECT * FROM $_table WHERE health_profile_id = ? ORDER BY taken_at DESC',
      variables: [Variable<String>(profile.value)],
    ).get();
    return rows.map((r) => _fromRow(r.data)).toList();
  }

  @override
  Future<List<RecordDocument>> findMany(Iterable<RecordDocumentId> keys, {HealthProfileId? scope}) async {
    final profile = _resolve(scope);
    if (profile == null || keys.isEmpty) return const [];
    final ids = keys.map((k) => k.value).toList();
    final placeholders = List.filled(ids.length, '?').join(', ');
    final rows = await _db.customSelect(
      'SELECT * FROM $_table WHERE health_profile_id = ? AND id IN ($placeholders) '
      'ORDER BY taken_at DESC',
      variables: [
        Variable<String>(profile.value),
        ...ids.map((id) => Variable<String>(id)),
      ],
    ).get();
    return rows.map((r) => _fromRow(r.data)).toList();
  }

  @override
  Future<bool> exists(RecordDocumentId key, {HealthProfileId? scope}) async => await find(key, scope: scope) != null;

  // ── Watch ────────────────────────────────────────────────────────────────

  @override
  Stream<RecordDocument?> watch(RecordDocumentId key, {HealthProfileId? scope}) {
    final profile = _resolve(scope);
    if (profile == null) return Stream.value(null);
    return Stream<RecordDocument?>.multi((emitter) async {
      emitter.add(await find(key, scope: profile));
      emitter.addStream(
        _changes.stream.asyncMap((_) => find(key, scope: profile)),
      );
    });
  }

  @override
  Stream<List<RecordDocument>> watchAll({HealthProfileId? scope}) {
    final profile = _resolve(scope);
    if (profile == null) return Stream.value(const []);
    return Stream<List<RecordDocument>>.multi((emitter) async {
      emitter.add(await findAll(scope: profile));
      emitter.addStream(
        _changes.stream.asyncMap((_) => findAll(scope: profile)),
      );
    });
  }

  // ── Writes ───────────────────────────────────────────────────────────────

  @override
  Future<void> put(RecordDocumentId key, RecordDocument value, {HealthProfileId? scope}) async {
    final profile = _require(scope);
    await _requireOwnedBy(profile, value.userId, 'record ${key.value}');
    try {
      await _db.customInsert(
        'INSERT OR REPLACE INTO $_table '
        '(id, user_id, health_profile_id, type, title, tags, source, '
        'file_type, file_path, pages, result_note, taken_at, created_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        variables: [
          Variable<String>(key.value),
          Variable<String>(value.userId.value),
          Variable<String>(profile.value),
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
  Future<void> putBulk(Map<RecordDocumentId, RecordDocument> values, {HealthProfileId? scope}) async {
    final profile = _require(scope);
    await _db.transaction(() async {
      for (final entry in values.entries) {
        await put(entry.key, entry.value, scope: profile);
      }
    });
    _notifyChanged();
  }

  @override
  Future<void> delete(RecordDocumentId key, {HealthProfileId? scope}) async {
    final profile = _require(scope);
    await _db.customUpdate(
      'DELETE FROM $_table WHERE id = ? AND health_profile_id = ?',
      variables: [Variable<String>(key.value), Variable<String>(profile.value)],
      updateKind: UpdateKind.delete,
    );
    _notifyChanged();
  }

  @override
  Future<void> deleteMany(Iterable<RecordDocumentId> keys, {HealthProfileId? scope}) async {
    final profile = _require(scope);
    if (keys.isEmpty) return;
    final ids = keys.map((k) => k.value).toList();
    final placeholders = List.filled(ids.length, '?').join(', ');
    await _db.customUpdate(
      'DELETE FROM $_table WHERE health_profile_id = ? AND id IN ($placeholders)',
      variables: [
        Variable<String>(profile.value),
        ...ids.map((id) => Variable<String>(id)),
      ],
      updateKind: UpdateKind.delete,
    );
    _notifyChanged();
  }

  @override
  Future<void> clear({HealthProfileId? scope}) async {
    final profile = _resolve(scope);
    if (profile == null) return; // idempotent logout cleanup
    await _db.customUpdate(
      'DELETE FROM $_table WHERE health_profile_id = ?',
      variables: [Variable<String>(profile.value)],
      updateKind: UpdateKind.delete,
    );
    _notifyChanged();
  }

  @override
  Future<void> clearAll() async {
    await _db.customUpdate('DELETE FROM $_table', updateKind: UpdateKind.delete);
    _notifyChanged();
  }

  /// A record is filed under a profile of the account that owns it — never
  /// under another account's person.
  Future<void> _requireOwnedBy(HealthProfileId profile, UserId owner, String what) async {
    final rows = await _db.customSelect(
      'SELECT 1 FROM health_profile WHERE id = ? AND user_id = ?',
      variables: [Variable<String>(profile.value), Variable<String>(owner.value)],
    ).get();
    if (rows.isEmpty) {
      throw StorageWriteException('$what: profile ${profile.value} is not owned by ${owner.value}');
    }
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
      throw StorageDecodeException('health_record row ${row['id']}: undecodable', e);
    }
  }
}

/// DI: profile-partitioned records vault bound to the active-profile port.
/// The app composition root only needs `appDatabaseProvider` overridden.
/// Exposed as the port, not the Drift class — callers must not be able to
/// reach past the contract into the storage engine.
final recordsDataSourceProvider = Provider<RecordsDataSource>((ref) {
  return DriftRecordsDataSource(
    ref.watch(appDatabaseProvider),
    () => ref.read(currentProfileIdProvider),
  );
});
