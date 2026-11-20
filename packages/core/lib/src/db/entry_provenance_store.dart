import 'package:drift/drift.dart';

import '../data_source/storage_exceptions.dart';
import '../domain/value_objects/entry_provenance.dart';
import '../domain/value_objects/health_profile_id.dart';
import 'app_database.dart';

/// Reads and appends the [EntryHistory] of patient entries in the shared
/// `entry_provenance` ledger. PHI (names of the people involved), on-device
/// only.
///
/// Used by the owning modules' drift data sources, each under its own
/// [entryKind] (its table name), so one module never reads another's history.
/// Rows are partitioned by `health_profile_id` like the entries they
/// describe. The ledger is append-only: [append] inserts events it has not
/// stored yet and never rewrites one, and a trigger refuses any change to a
/// stored event.
class EntryProvenanceStore {
  const EntryProvenanceStore(this._db, this.entryKind);

  final AppDatabase _db;

  /// Which kind of entry this store keeps history for (`health_record`,
  /// `medications`, `check_in`).
  final String entryKind;

  static const _table = 'entry_provenance';

  /// The history of entry [entryId] filed under [profile].
  Future<EntryHistory> historyOf(String entryId, HealthProfileId profile) async {
    final rows = await _db.customSelect(
      'SELECT * FROM $_table WHERE entry_kind = ? AND entry_id = ? AND health_profile_id = ? ORDER BY rowid',
      variables: [Variable<String>(entryKind), Variable<String>(entryId), Variable<String>(profile.value)],
    ).get();
    return EntryHistory(List.unmodifiable(rows.map((r) => _fromRow(r.data))));
  }

  /// Every history of this kind under [profile], by entry id. Entries with no
  /// history are absent.
  Future<Map<String, EntryHistory>> historiesOf(HealthProfileId profile) async {
    final rows = await _db.customSelect(
      'SELECT * FROM $_table WHERE entry_kind = ? AND health_profile_id = ? ORDER BY rowid',
      variables: [Variable<String>(entryKind), Variable<String>(profile.value)],
    ).get();
    final byEntry = <String, List<ProvenanceEvent>>{};
    for (final r in rows) {
      (byEntry[r.data['entry_id'] as String] ??= []).add(_fromRow(r.data));
    }
    return byEntry.map((id, events) => MapEntry(id, EntryHistory(List.unmodifiable(events))));
  }

  /// Stores the events of [history] not stored yet, in order. Events already
  /// in the ledger are left exactly as they are.
  Future<void> append(String entryId, HealthProfileId profile, EntryHistory history) async {
    for (final e in history.events) {
      await _db.customInsert(
        'INSERT OR IGNORE INTO $_table '
        '(id, health_profile_id, entry_kind, entry_id, actor_kind, actor_name, care_provider_id, action, occurred_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        variables: [
          Variable<String>(e.id),
          Variable<String>(profile.value),
          Variable<String>(entryKind),
          Variable<String>(entryId),
          Variable<String>(e.actor.kind.wire),
          Variable<String>(e.actor.displayName),
          Variable<String>(e.actor.careProviderId),
          Variable<String>(e.action.wire),
          Variable<String>(e.at.toUtc().toIso8601String()),
        ],
      );
    }
  }

  ProvenanceEvent _fromRow(Map<String, dynamic> row) {
    try {
      final kind = ProvenanceActorKind.fromWire(row['actor_kind'] as String);
      return ProvenanceEvent(
        id: row['id'] as String,
        actor: kind == ProvenanceActorKind.self
            ? ProvenanceActor.self
            : ProvenanceActor.other(
                kind,
                displayName: row['actor_name'] as String?,
                careProviderId: row['care_provider_id'] as String?,
              ),
        action: ProvenanceAction.fromWire(row['action'] as String),
        at: DateTime.parse(row['occurred_at'] as String),
      );
    } catch (e) {
      throw StorageDecodeException('$_table row ${row['id']}: undecodable', e);
    }
  }
}
