import 'package:drift/drift.dart';

import '../db/app_database.dart';
import 'outbox_entry.dart';

/// Durable push queue for cloud sync (FR-506).
///
/// Ordering is strict FIFO by rowid across the whole queue, which is what makes
/// an upsert-then-delete of the same id safe: draining out of order would
/// tombstone the row and then re-create it, resurrecting something the patient
/// deleted.
class SyncOutboxDao {
  const SyncOutboxDao(this._db);

  final AppDatabase _db;

  Future<void> enqueue({
    required String entity,
    required String entityId,
    required OutboxOp op,
    required String payload,
  }) async {
    await _db.customInsert(
      '''
      INSERT INTO sync_outbox (entity, entity_id, op, payload, created_at, attempts)
      VALUES (?, ?, ?, ?, ?, 0)
      ''',
      variables: [
        Variable.withString(entity),
        Variable.withString(entityId),
        Variable.withString(op.name),
        Variable.withString(payload),
        Variable.withInt(DateTime.now().millisecondsSinceEpoch),
      ],
    );
  }

  /// The oldest [limit] queued changes, oldest first.
  Future<List<OutboxEntry>> pending({int limit = 100}) async {
    final rows = await _db.customSelect(
      'SELECT * FROM sync_outbox ORDER BY id ASC LIMIT ?',
      variables: [Variable.withInt(limit)],
    ).get();
    return rows
        .map((r) => OutboxEntry(
              id: r.read<int>('id'),
              entity: r.read<String>('entity'),
              entityId: r.read<String>('entity_id'),
              op: OutboxOp.fromId(r.read<String>('op')),
              payload: r.read<String>('payload'),
              createdAt: DateTime.fromMillisecondsSinceEpoch(r.read<int>('created_at'), isUtc: true),
              attempts: r.read<int>('attempts'),
            ))
        .toList();
  }

  /// Drops a successfully pushed entry.
  Future<void> complete(int id) async {
    await _db.customStatement('DELETE FROM sync_outbox WHERE id = ?', [id]);
  }

  /// Keeps the entry queued and records why the push failed.
  Future<void> fail(int id, String error) async {
    await _db.customStatement(
      'UPDATE sync_outbox SET attempts = attempts + 1, last_error = ? WHERE id = ?',
      [error, id],
    );
  }

  Future<int> pendingCount() async {
    final row = await _db.customSelect('SELECT COUNT(*) AS c FROM sync_outbox').getSingle();
    return row.read<int>('c');
  }
}
