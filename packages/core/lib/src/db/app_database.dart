import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Conditional executor: native (dart:ffi) on device, deferred-throw on web.
import 'database_connection_web.dart' if (dart.library.ffi) 'database_connection_io.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {},
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          // Raw-SQL on-device PHI schema (DAOs use customSelect/Insert; no
          // generated drift tables yet). Idempotent — safe on every open.
          for (final stmt in _phiSchema) {
            await customStatement(stmt);
          }
        },
      );

  static Future<AppDatabase> open() async => AppDatabase(openExecutor());
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('AppDatabase must be initialized in bootstrap()');
});

/// On-device PHI schema (matches the raw SQL in profile/medications DAOs).
/// All `IF NOT EXISTS` so `beforeOpen` is idempotent.
const _phiSchema = <String>[
  '''
  CREATE TABLE IF NOT EXISTS health_profile (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    blood_type TEXT,
    updated_at TEXT NOT NULL
  )''',
  '''
  CREATE TABLE IF NOT EXISTS allergy (
    id TEXT PRIMARY KEY,
    health_profile_id TEXT NOT NULL REFERENCES health_profile(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    severity TEXT NOT NULL,
    is_controlled_substance INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL
  )''',
  '''
  CREATE TABLE IF NOT EXISTS chronic_condition (
    id TEXT PRIMARY KEY,
    health_profile_id TEXT NOT NULL REFERENCES health_profile(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    created_at TEXT NOT NULL
  )''',
  '''
  CREATE TABLE IF NOT EXISTS emergency_contact (
    id TEXT PRIMARY KEY,
    health_profile_id TEXT NOT NULL REFERENCES health_profile(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    phone TEXT NOT NULL,
    relation TEXT,
    is_primary INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL
  )''',
  '''
  CREATE TABLE IF NOT EXISTS medications (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    name TEXT NOT NULL,
    dose_amount TEXT,
    schedule_type TEXT NOT NULL,
    schedule_config TEXT NOT NULL,
    start_date TEXT NOT NULL,
    end_date TEXT,
    is_controlled INTEGER NOT NULL DEFAULT 0
  )''',
  '''
  CREATE TABLE IF NOT EXISTS dose_events (
    id TEXT PRIMARY KEY,
    medication_id TEXT NOT NULL REFERENCES medications(id),
    scheduled_at TEXT NOT NULL,
    recorded_at TEXT NOT NULL,
    outcome TEXT NOT NULL,
    parent_event_id TEXT,
    snooze_until TEXT
  )''',
  // Append-only invariant (FR-019): dose events cannot be updated or deleted.
  '''
  CREATE TRIGGER IF NOT EXISTS dose_events_no_update
  BEFORE UPDATE ON dose_events
  BEGIN SELECT RAISE(ABORT, 'dose_events is append-only'); END''',
  '''
  CREATE TRIGGER IF NOT EXISTS dose_events_no_delete
  BEFORE DELETE ON dose_events
  BEGIN SELECT RAISE(ABORT, 'dose_events is append-only'); END''',
];
