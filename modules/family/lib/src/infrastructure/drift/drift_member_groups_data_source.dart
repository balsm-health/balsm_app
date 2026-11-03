import 'dart:async';

import 'package:core/core.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/ports/member_groups_data_source.dart';
import '../../domain/aggregates/member_group.dart';
import '../../domain/value_objects/default_group.dart';

/// Drift-backed [MemberGroupsDataSource] over the raw-SQL `member_group`
/// table in core's encrypted database.
///
/// Scope semantics (per `ScopedDataSource`): `scope == null` resolves the
/// signed-in account from [activeUser]; signed out → reads return null/empty,
/// mutations throw [NoActiveUserException], [clear] is an idempotent no-op.
/// [delete] only stamps `deleted_at`.
class DriftMemberGroupsDataSource extends MemberGroupsDataSource {
  DriftMemberGroupsDataSource({required AppDatabase db, required this.activeUser}) : _db = db;

  final AppDatabase _db;

  /// Resolves the signed-in account at call time (null = signed out).
  final UserId? Function() activeUser;

  static const _live = 'deleted_at IS NULL';
  static const _order = 'ORDER BY sort ASC, rowid ASC';

  /// Change signal for the watch streams — the table is raw SQL, so drift's
  /// table-based invalidation cannot fire.
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

  @override
  Future<MemberGroup?> find(MemberGroupId key, {UserId? scope}) async {
    final user = _resolve(scope);
    if (user == null) return null;
    final rows = await _db.customSelect(
      'SELECT * FROM member_group WHERE id = ? AND user_id = ? AND $_live LIMIT 1',
      variables: [Variable.withString(key.value), Variable.withString(user.value)],
    ).get();
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  @override
  Future<List<MemberGroup>> findAll({UserId? scope}) async {
    final user = _resolve(scope);
    if (user == null) return const [];
    final rows = await _db.customSelect(
      'SELECT * FROM member_group WHERE user_id = ? AND $_live $_order',
      variables: [Variable.withString(user.value)],
    ).get();
    return rows.map(_fromRow).toList();
  }

  @override
  Future<List<MemberGroup>> findMany(Iterable<MemberGroupId> keys, {UserId? scope}) async {
    final wanted = {for (final k in keys) k};
    return (await findAll(scope: scope)).where((g) => wanted.contains(g.id)).toList();
  }

  @override
  Future<bool> exists(MemberGroupId key, {UserId? scope}) async => await find(key, scope: scope) != null;

  @override
  Future<void> put(MemberGroupId key, MemberGroup value, {UserId? scope}) async {
    await _write(key, value, _require(scope));
    _notifyChanged();
  }

  @override
  Future<void> putBulk(Map<MemberGroupId, MemberGroup> values, {UserId? scope}) async {
    final user = _require(scope);
    await _db.transaction(() async {
      for (final e in values.entries) {
        await _write(e.key, e.value, user);
      }
    });
    _notifyChanged();
  }

  Future<void> _write(MemberGroupId key, MemberGroup value, UserId user) async {
    try {
      await _db.customInsert(
        '''
        INSERT INTO member_group (id, user_id, system_key, name, sort, created_at)
        VALUES (?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET name = excluded.name, sort = excluded.sort
          WHERE member_group.user_id = excluded.user_id
        ''',
        variables: [
          Variable.withString(key.value),
          Variable.withString(user.value),
          Variable<String>(value.defaultGroup?.key),
          // A default group's name is written at display time; the column
          // keeps its key so the row never reads as blank.
          Variable.withString(value.name ?? value.defaultGroup!.key),
          Variable.withInt(value.sort),
          Variable.withInt(value.createdAt.millisecondsSinceEpoch),
        ],
      );
    } catch (e) {
      throw StorageWriteException('member_group ${key.value}: write failed', e);
    }
  }

  /// Soft delete: the row stays, stamped `deleted_at`.
  @override
  Future<void> delete(MemberGroupId key, {UserId? scope}) async {
    final user = _require(scope);
    await _db.customUpdate(
      'UPDATE member_group SET deleted_at = ? WHERE id = ? AND user_id = ? AND $_live',
      variables: [
        Variable.withInt(DateTime.now().millisecondsSinceEpoch),
        Variable.withString(key.value),
        Variable.withString(user.value),
      ],
      updateKind: UpdateKind.update,
    );
    _notifyChanged();
  }

  @override
  Future<void> deleteMany(Iterable<MemberGroupId> keys, {UserId? scope}) async {
    for (final k in keys) {
      await delete(k, scope: scope);
    }
  }

  /// Account wipe: removes the account's rows outright.
  @override
  Future<void> clear({UserId? scope}) async {
    final user = _resolve(scope);
    if (user == null) return;
    await _db.customUpdate(
      'DELETE FROM member_group WHERE user_id = ?',
      variables: [Variable.withString(user.value)],
      updateKind: UpdateKind.delete,
    );
    _notifyChanged();
  }

  @override
  Future<void> clearAll() async {
    await _db.customUpdate('DELETE FROM member_group', updateKind: UpdateKind.delete);
    _notifyChanged();
  }

  @override
  Stream<MemberGroup?> watch(MemberGroupId key, {UserId? scope}) {
    final user = _resolve(scope);
    if (user == null) return Stream.value(null);
    return _watch(() => find(key, scope: user));
  }

  @override
  Stream<List<MemberGroup>> watchAll({UserId? scope}) {
    final user = _resolve(scope);
    if (user == null) return Stream.value(const []);
    return _watch(() => findAll(scope: user));
  }

  Stream<T> _watch<T>(Future<T> Function() read) => Stream<T>.multi((emitter) async {
        emitter.add(await read());
        emitter.addStream(_changes.stream.asyncMap((_) => read()));
      });

  static MemberGroup _fromRow(QueryRow row) {
    final key = DefaultGroup.tryFromKey(row.readNullable<String>('system_key'));
    return MemberGroup(
      id: MemberGroupId.value(row.read<String>('id')),
      userId: UserId.value(row.read<String>('user_id')),
      defaultGroup: key,
      name: key == null ? row.read<String>('name') : null,
      sort: row.read<int>('sort'),
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.read<int>('created_at'), isUtc: true),
    );
  }
}

/// Bound to the signed-in account via core's `currentUserIdProvider`;
/// requires [appDatabaseProvider] to be overridden at bootstrap.
final memberGroupsDataSourceProvider = Provider<MemberGroupsDataSource>((ref) {
  return DriftMemberGroupsDataSource(
    db: ref.watch(appDatabaseProvider),
    activeUser: () => ref.read(currentUserIdProvider),
  );
});
