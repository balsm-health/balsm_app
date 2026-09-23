/// What a queued change does to the server row.
enum OutboxOp {
  /// Create-or-overwrite. Covers both add and update — the server handler is
  /// idempotent on id, so the client never distinguishes them.
  upsert,

  /// Tombstone.
  delete;

  static OutboxOp fromId(String id) => OutboxOp.values.firstWhere((o) => o.name == id, orElse: () => OutboxOp.upsert);
}

/// One queued local change awaiting push to the cloud.
class OutboxEntry {
  const OutboxEntry({
    required this.id,
    required this.entity,
    required this.entityId,
    required this.op,
    required this.payload,
    required this.createdAt,
    required this.attempts,
  });

  /// Monotonic rowid — also the FIFO ordering key.
  final int id;

  /// Table this change belongs to, e.g. `care_provider`.
  final String entity;

  /// Primary key of the changed row.
  final String entityId;

  final OutboxOp op;

  /// JSON body to send. Empty object for a delete.
  final String payload;

  final DateTime createdAt;

  /// Failed push count, for backoff and for surfacing a stuck queue.
  final int attempts;
}
