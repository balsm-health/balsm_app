import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/value_objects/health_profile_id.dart';
import '../domain/value_objects/user_id.dart';
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
          // Idempotent column patches for PHI tables that gained columns after
          // their initial CREATE. `CREATE TABLE IF NOT EXISTS` above does not
          // alter a pre-existing table, so add any missing columns for dev DBs.
          await _ensureColumn('chronic_condition', 'icd10_code', 'TEXT');
          await _ensureColumn('chronic_condition', 'onset_year', 'INTEGER');
          // Dependants seam (P00X forward-compat): medications + health_record
          // anchor to health_profile, not just user_id. Nullable until a self
          // profile row is guaranteed at sign-in (F1); the convergent backfill
          // below fills it as profile rows appear. Queries still filter on
          // user_id — re-keying the DAOs lands with the dependants feature.
          await _ensureColumn('medications', 'health_profile_id', 'TEXT');
          await _ensureColumn('health_record', 'health_profile_id', 'TEXT');
          await runProfileAnchorBackfill();
        },
      );

  /// Idempotently adds [column] (with SQL [ddlType]) to [table] when it is not
  /// already present. Evolves the raw-SQL PHI schema (see [_phiSchema]) without
  /// a full drift migration; safe to run on every open.
  Future<void> _ensureColumn(String table, String column, String ddlType) async {
    final info = await customSelect('PRAGMA table_info($table)').get();
    final hasColumn = info.any((r) => r.read<String>('name') == column);
    if (!hasColumn) {
      await customStatement('ALTER TABLE $table ADD COLUMN $column $ddlType');
    }
  }

  /// Anchors any NULL `health_profile_id` rows to their user's profile row
  /// (convergent, idempotent). Runs on every open and again after
  /// [ensureSelfHealthProfile] creates a profile row mid-session.
  Future<void> runProfileAnchorBackfill() async {
    for (final table in ['medications', 'health_record']) {
      await customStatement('''
        UPDATE $table SET health_profile_id =
          (SELECT hp.id FROM health_profile hp
            WHERE hp.user_id = $table.user_id)
        WHERE health_profile_id IS NULL''');
    }
  }

  /// Returns [userId]'s self health-profile id, creating the (empty) row on
  /// first call — the guarantee behind `currentProfileIdProvider`: every
  /// signed-in session has an active profile scope. Also re-runs the anchor
  /// backfill so rows written before the profile existed converge immediately.
  Future<HealthProfileId> ensureSelfHealthProfile(UserId userId) async {
    final existing = await customSelect(
      'SELECT id FROM health_profile WHERE user_id = ? LIMIT 1',
      variables: [Variable.withString(userId.value)],
    ).get();
    if (existing.isNotEmpty) {
      return HealthProfileId.value(existing.first.read<String>('id'));
    }
    final id = HealthProfileId.uuid();
    // updated_at is epoch-millis (matches the profile DAO's hydration).
    await customInsert(
      'INSERT INTO health_profile (id, user_id, updated_at) VALUES (?, ?, ?)',
      variables: [
        Variable.withString(id.value),
        Variable.withString(userId.value),
        Variable.withInt(DateTime.now().millisecondsSinceEpoch),
      ],
    );
    await runProfileAnchorBackfill();
    return id;
  }

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
    icd10_code TEXT,
    onset_year INTEGER,
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
    health_profile_id TEXT,
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
  // Health-record vault metadata (records module). The document bytes live in
  // the app documents dir (file_path); this row is the searchable index.
  '''
  CREATE TABLE IF NOT EXISTS health_record (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    health_profile_id TEXT,
    type TEXT NOT NULL,
    title TEXT NOT NULL,
    tags TEXT NOT NULL,
    source TEXT NOT NULL,
    file_type TEXT,
    file_path TEXT,
    pages INTEGER,
    result_note TEXT,
    taken_at TEXT NOT NULL,
    created_at TEXT NOT NULL
  )''',
  // Profile-anchor indexes (dependants seam) — cheap now, required once
  // queries re-key from user_id to health_profile_id.
  'CREATE INDEX IF NOT EXISTS idx_medications_profile ON medications(health_profile_id)',
  'CREATE INDEX IF NOT EXISTS idx_health_record_profile ON health_record(health_profile_id)',
  // Disclosure/consent acceptance ledger (disclosure module). PHI-free —
  // records which disclosure version the user accepted and the jurisdiction
  // context at accept time. One row per (disclosure_id, version).
  '''
  CREATE TABLE IF NOT EXISTS disclosure_acceptance (
    id TEXT PRIMARY KEY,
    disclosure_id TEXT NOT NULL,
    version TEXT NOT NULL,
    country_code TEXT NOT NULL,
    supervisory_authority_name TEXT NOT NULL,
    preferred_language TEXT NOT NULL,
    accepted_at INTEGER NOT NULL,
    UNIQUE(disclosure_id, version)
  )''',
];
