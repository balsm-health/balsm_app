import 'package:drift/drift.dart';

/// Every table that has a column named [column], discovered from the schema
/// rather than a hard-coded list, so a module that adds such a table later is
/// covered without touching the helpers below.
Future<List<String>> tablesWithColumn(GeneratedDatabase db, String column) async {
  final rows = await db.customSelect(
    "SELECT m.name AS t FROM sqlite_master m "
    "WHERE m.type = 'table' AND m.name NOT LIKE 'sqlite_%' "
    "AND EXISTS (SELECT 1 FROM pragma_table_info(m.name) c WHERE c.name = ?)",
    variables: [Variable.withString(column)],
  ).get();
  return [for (final r in rows) r.read<String>('t')];
}

/// Every table whose rows are owned by an account (has a `user_id` column).
Future<List<String>> ownedTables(GeneratedDatabase db) => tablesWithColumn(db, 'user_id');

/// Moves every locally-owned row from account [from] to account [to].
///
/// Discovers tables by column (see [ownedTables]). One transaction: a crash
/// leaves either every row on [from] or every row on [to].
Future<int> rekeyOwner(
  GeneratedDatabase db, {
  required String from,
  required String to,
  required bool dropOutbox,
}) async {
  if (from == to) return 0;
  return db.transaction(() => _rekeyRows(db, from: from, to: to, dropOutbox: dropOutbox));
}

/// Merges the offline account [from] into the existing account [to], which
/// may already have used this phone.
///
/// `health_profile` has no UNIQUE(user_id), so a plain re-key could leave the
/// merged account with two self profiles. When [to] already owns one, every
/// `health_profile_id` column pointing at [from]'s profile is re-pointed to
/// [to]'s, and [from]'s now-empty profile row is deleted — after copying its
/// blood type, weight and height into any of those [to] has left NULL, and
/// demoting [from]'s primary emergency contact if [to] already has one. Then every
/// `user_id` row moves, dropping [from]'s outbox rows. All in one
/// transaction; a second run finds nothing owned by [from] and does nothing.
Future<int> mergeOwner(GeneratedDatabase db, {required String from, required String to}) async {
  if (from == to) return 0;
  return db.transaction(() async {
    var changed = 0;
    final owned = await ownedTables(db);
    if (owned.contains('health_profile')) {
      final target = await db.customSelect(
        'SELECT id FROM health_profile WHERE user_id = ? ORDER BY rowid LIMIT 1',
        variables: [Variable.withString(to)],
      ).get();
      if (target.isNotEmpty) {
        final targetId = target.first.read<String>('id');
        final offline = await db.customSelect(
          'SELECT id FROM health_profile WHERE user_id = ?',
          variables: [Variable.withString(from)],
        ).get();
        final children = await tablesWithColumn(db, 'health_profile_id');
        final headCols = await _columnsOf(db, 'health_profile');
        final hasPrimaryFlag = (await _columnsOf(db, 'emergency_contact')).contains('is_primary');
        for (final p in offline) {
          final pid = p.read<String>('id');
          // The offline profile row is about to go: keep any head field the
          // target has never filled in, so the merge doesn't drop it.
          for (final c in _profileHeadFields) {
            if (!headCols.contains(c)) continue;
            changed += await db.customUpdate(
                'UPDATE health_profile SET "$c" = COALESCE("$c", (SELECT "$c" FROM health_profile WHERE id = ?)) '
                'WHERE id = ?',
                variables: [Variable.withString(pid), Variable.withString(targetId)],
                updateKind: UpdateKind.update);
          }
          // One primary emergency contact per profile: if the target already
          // has one, the offline contacts join as non-primary.
          if (hasPrimaryFlag) {
            changed += await db.customUpdate(
                'UPDATE emergency_contact SET is_primary = 0 WHERE health_profile_id = ? AND is_primary <> 0 '
                'AND EXISTS (SELECT 1 FROM emergency_contact WHERE health_profile_id = ? AND is_primary <> 0)',
                variables: [Variable.withString(pid), Variable.withString(targetId)],
                updateKind: UpdateKind.update);
          }
          for (final t in children) {
            changed += await db.customUpdate('UPDATE "$t" SET health_profile_id = ? WHERE health_profile_id = ?',
                variables: [Variable.withString(targetId), Variable.withString(pid)], updateKind: UpdateKind.update);
          }
          changed += await db.customUpdate('DELETE FROM health_profile WHERE id = ?',
              variables: [Variable.withString(pid)], updateKind: UpdateKind.delete);
        }
      }
    }
    return changed + await _rekeyRows(db, from: from, to: to, dropOutbox: true);
  });
}

/// `health_profile` columns that describe the person (not bookkeeping) and
/// are kept from the offline profile on merge when the target's are NULL.
const _profileHeadFields = ['blood_type', 'weight_kg', 'height_cm'];

Future<Set<String>> _columnsOf(GeneratedDatabase db, String table) async {
  final rows =
      await db.customSelect('SELECT name FROM pragma_table_info(?)', variables: [Variable.withString(table)]).get();
  return {for (final r in rows) r.read<String>('name')};
}

/// Deletes everything account [owner] has on this device: every `user_id`
/// row, every row keyed to one of its health profiles, and — following
/// foreign keys down — every row that depends on those (e.g. dose events
/// under a medication), children before parents so a non-cascading foreign
/// key never blocks the delete. One transaction; idempotent.
Future<int> discardOwner(GeneratedDatabase db, {required String owner}) async {
  return db.transaction(() async {
    var changed = 0;
    final owned = await ownedTables(db);
    final vars = [Variable.withString(owner)];
    if (owned.contains('health_profile')) {
      for (final t in await tablesWithColumn(db, 'health_profile_id')) {
        changed += await _deleteWhere(
            db, t, 'health_profile_id IN (SELECT id FROM health_profile WHERE user_id = ?)', vars, const []);
      }
    }
    for (final t in owned) {
      changed += await _deleteWhere(db, t, 'user_id = ?', vars, const []);
    }
    return changed;
  });
}

Future<int> _rekeyRows(
  GeneratedDatabase db, {
  required String from,
  required String to,
  required bool dropOutbox,
}) async {
  var changed = 0;
  for (final t in await ownedTables(db)) {
    if (dropOutbox && t == 'sync_outbox') {
      changed += await db.customUpdate('DELETE FROM "$t" WHERE user_id = ?',
          variables: [Variable.withString(from)], updateKind: UpdateKind.delete);
    } else {
      changed += await db.customUpdate('UPDATE "$t" SET user_id = ? WHERE user_id = ?',
          variables: [Variable.withString(to), Variable.withString(from)], updateKind: UpdateKind.update);
    }
  }
  return changed;
}

/// Deletes the rows of [table] matching [where], after first deleting (the
/// same way) every row in another table whose foreign key points at them.
/// [path] guards against reference cycles.
Future<int> _deleteWhere(
  GeneratedDatabase db,
  String table,
  String where,
  List<Variable> vars,
  List<String> path,
) async {
  var changed = 0;
  final refs = await db.customSelect(
    "SELECT m.name AS child, f.\"from\" AS col, f.\"to\" AS parent_col "
    "FROM sqlite_master m, pragma_foreign_key_list(m.name) f "
    "WHERE m.type = 'table' AND lower(f.\"table\") = lower(?)",
    variables: [Variable.withString(table)],
  ).get();
  for (final r in refs) {
    final child = r.read<String>('child');
    if (child == table || path.contains(child)) continue;
    final parentCol = r.readNullable<String>('parent_col') ?? await _primaryKey(db, table);
    final col = r.read<String>('col');
    changed += await _deleteWhere(
      db,
      child,
      '"$col" IN (SELECT "$parentCol" FROM "$table" WHERE $where)',
      vars,
      [...path, table],
    );
  }
  // The append-only dose-history guard (FR-019) protects history from edits.
  // Approved by the product owner: discarding a device-only account deletes
  // its dose history, so that one guard — and only that one, by name — is
  // lifted for this statement and put back straight after, inside the
  // caller's transaction (a failure restores it with the rows). Any other
  // delete guard is a compliance rule nobody approved bypassing: throw.
  final guards = await db.customSelect(
    "SELECT name, sql FROM sqlite_master WHERE type = 'trigger' AND lower(tbl_name) = lower(?)",
    variables: [Variable.withString(table)],
  ).get();
  final lifted = <({String name, String sql})>[];
  for (final g in guards) {
    final sql = g.read<String>('sql');
    if (!_isDeleteGuard(sql)) continue;
    final name = g.read<String>('name');
    if (!kDiscardLiftableTriggers.contains(name)) {
      throw StateError('a delete guard blocks discarding this table');
    }
    lifted.add((name: name, sql: sql));
  }
  for (final g in lifted) {
    await db.customStatement('DROP TRIGGER "${g.name}"');
  }
  changed += await db.customUpdate('DELETE FROM "$table" WHERE $where', variables: vars, updateKind: UpdateKind.delete);
  for (final g in lifted) {
    await db.customStatement(g.sql);
  }
  return changed;
}

/// Delete-guard triggers [discardOwner] may lift. Only the FR-019 dose-history
/// guard, by explicit product-owner approval; adding to this list is a
/// compliance decision, not a code one.
const kDiscardLiftableTriggers = {'dose_events_no_delete'};

bool _isDeleteGuard(String sql) {
  final s = sql.toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
  return s.contains('BEFORE DELETE ON') && s.contains('RAISE(ABORT');
}

/// The single-column primary key of [table] (a foreign key that names no
/// parent column references it); `rowid` when there is none.
Future<String> _primaryKey(GeneratedDatabase db, String table) async {
  final rows = await db.customSelect(
    'SELECT name FROM pragma_table_info(?) WHERE pk = 1',
    variables: [Variable.withString(table)],
  ).get();
  return rows.isEmpty ? 'rowid' : rows.first.read<String>('name');
}
