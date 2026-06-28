import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/app_database.dart';

/// Snapshot read/write surface (lets the backup/restore services be unit-tested
/// without a real database).
abstract interface class SnapshotPort {
  Future<Map<String, dynamic>> export();
  Future<void> import(Map<String, dynamic> snapshot);
}

/// Exports and imports the on-device PHI database as a plain JSON map, suitable
/// for encryption into the backup blob and merge-restore on another device.
///
/// Merge policy per table:
/// - `health_profile`: last-writer-wins by `updated_at` (single mutable row).
/// - everything else: union by primary key (`INSERT OR IGNORE`) — lossless on
///   restore-onto-empty and safe for the append-only `dose_events` trigger.
class SnapshotService implements SnapshotPort {
  SnapshotService(this._db);

  final AppDatabase _db;

  static const schemaVersion = 1;

  /// Tables captured, in FK-safe insert order (parents before children).
  static const _tables = [
    'health_profile',
    'allergy',
    'chronic_condition',
    'emergency_contact',
    'medications',
    'dose_events',
  ];

  /// Reads every PHI table into a JSON-serializable snapshot.
  Future<Map<String, dynamic>> export() async {
    final tables = <String, List<Map<String, dynamic>>>{};
    for (final t in _tables) {
      final rows = await _db.customSelect('SELECT * FROM $t').get();
      tables[t] = rows.map((r) => Map<String, dynamic>.from(r.data)).toList();
    }
    return {
      'schemaVersion': schemaVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'tables': tables,
    };
  }

  /// Merges a snapshot into the local DB. Idempotent and FK-safe.
  Future<void> import(Map<String, dynamic> snapshot) async {
    final tables = (snapshot['tables'] as Map?)?.cast<String, dynamic>() ?? {};
    await _db.transaction(() async {
      for (final t in _tables) {
        final rows = (tables[t] as List?)?.cast<Map<String, dynamic>>() ?? const [];
        for (final row in rows) {
          if (t == 'health_profile') {
            await _lwwUpsert(t, row);
          } else {
            await _insertIgnore(t, row);
          }
        }
      }
    });
  }

  Future<void> _insertIgnore(String table, Map<String, dynamic> row) async {
    final cols = row.keys.toList();
    final placeholders = List.filled(cols.length, '?').join(', ');
    await _db.customStatement(
      'INSERT OR IGNORE INTO $table (${cols.join(', ')}) VALUES ($placeholders)',
      cols.map((c) => row[c]).toList(),
    );
  }

  /// Last-writer-wins by `updated_at`: replace only when the incoming row is
  /// newer (or no local row exists for that id).
  Future<void> _lwwUpsert(String table, Map<String, dynamic> row) async {
    final id = row['id'];
    final incoming = DateTime.tryParse('${row['updated_at']}');
    final existing = await _db
        .customSelect('SELECT updated_at FROM $table WHERE id = ?', variables: [_v(id)])
        .getSingleOrNull();
    if (existing != null) {
      final local = DateTime.tryParse('${existing.data['updated_at']}');
      if (local != null && incoming != null && !incoming.isAfter(local)) return;
    }
    final cols = row.keys.toList();
    final placeholders = List.filled(cols.length, '?').join(', ');
    await _db.customStatement(
      'INSERT OR REPLACE INTO $table (${cols.join(', ')}) VALUES ($placeholders)',
      cols.map((c) => row[c]).toList(),
    );
  }
}

// Wrap a dynamic value as a drift Variable for customSelect bindings.
Variable _v(Object? value) => Variable(value);

final snapshotServiceProvider = Provider<SnapshotService>(
  (ref) => SnapshotService(ref.watch(appDatabaseProvider)),
);
