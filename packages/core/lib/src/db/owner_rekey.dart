import 'package:drift/drift.dart';

/// Moves every locally-owned row from account [from] to account [to].
///
/// Discovers tables by column rather than a hard-coded list, so a module that
/// adds a `user_id` table later is covered without touching this. One
/// transaction: a crash leaves either every row on [from] or every row on [to].
Future<int> rekeyOwner(
  GeneratedDatabase db, {
  required String from,
  required String to,
  required bool dropOutbox,
}) async {
  if (from == to) return 0;
  return db.transaction(() async {
    final tables = await db
        .customSelect(
          "SELECT m.name AS t FROM sqlite_master m "
          "WHERE m.type = 'table' AND m.name NOT LIKE 'sqlite_%' "
          "AND EXISTS (SELECT 1 FROM pragma_table_info(m.name) c WHERE c.name = 'user_id')",
        )
        .get();
    var changed = 0;
    for (final row in tables) {
      final t = row.read<String>('t');
      if (dropOutbox && t == 'sync_outbox') {
        changed += await db.customUpdate('DELETE FROM "$t" WHERE user_id = ?',
            variables: [Variable.withString(from)], updateKind: UpdateKind.delete);
      } else {
        changed += await db.customUpdate('UPDATE "$t" SET user_id = ? WHERE user_id = ?',
            variables: [Variable.withString(to), Variable.withString(from)], updateKind: UpdateKind.update);
      }
    }
    return changed;
  });
}
