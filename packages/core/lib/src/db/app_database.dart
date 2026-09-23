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
          for (final stmt in _cacheSchema) {
            await customStatement(stmt);
          }
          for (final stmt in _mapPacksSchema) {
            await customStatement(stmt);
          }

          // Idempotent column patches for PHI tables that gained columns after
          // their initial CREATE. `CREATE TABLE IF NOT EXISTS` above does not
          // alter a pre-existing table, so add any missing columns for dev DBs.
          await _ensureColumn('chronic_condition', 'icd10_code', 'TEXT');
          await _ensureColumn('chronic_condition', 'onset_year', 'INTEGER');
          await _ensureColumn('health_profile', 'weight_kg', 'REAL');
          await _ensureColumn('health_profile', 'height_cm', 'REAL');
          // Dependants seam (P00X forward-compat): medications + health_record
          // anchor to health_profile, not just user_id. Nullable until a self
          // profile row is guaranteed at sign-in (F1); the convergent backfill
          // below fills it as profile rows appear. Queries still filter on
          // user_id — re-keying the DAOs lands with the dependants feature.
          await _ensureColumn('medications', 'health_profile_id', 'TEXT');
          await _ensureColumn('health_record', 'health_profile_id', 'TEXT');
          await _ensureColumn('prescription', 'title', 'TEXT');
          await _ensureColumn('prescription', 'source', 'TEXT');
          await _ensureColumn('prescription', 'attachment_path', 'TEXT');
          await _ensureColumn('prescription', 'attachment_kind', 'TEXT');
          await _ensureColumn('check_in_symptom', 'urine_color', 'TEXT');
          await _ensureColumn('check_in_symptom', 'urine_ml', 'INTEGER');
          await _ensureColumn('check_in_symptom', 'blood', 'INTEGER NOT NULL DEFAULT 0');
          await _ensureColumn('care_provider', 'map_url', 'TEXT');
          // Cloud-sync bookkeeping (FR-507/FR-508). Nullable so pre-existing rows
          // migrate without a backfill; the sync service treats a null updated_at
          // as created_at.
          await _ensureColumn('care_provider', 'updated_at', 'INTEGER');
          await _ensureColumn('care_provider', 'deleted_at', 'INTEGER');
          await _ensurePainSitePk();
          // These indexes must be created AFTER the column patches above — on a
          // pre-existing DB the `medications`/`health_record` tables predate
          // `health_profile_id`, so indexing it inside `_phiSchema` (which runs
          // before the patches) would fail with "no such column".
          await customStatement('CREATE INDEX IF NOT EXISTS idx_medications_profile ON medications(health_profile_id)');
          await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_health_record_profile ON health_record(health_profile_id)');
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

  /// Rebuilds `check_in_pain_region` so one check-in can store the same region
  /// on more than one tissue. Pre-existing rows become `tissue_id = 'muscle'`.
  Future<void> _ensurePainSitePk() async {
    final info = await customSelect('PRAGMA table_info(check_in_pain_region)').get();
    if (info.isEmpty) return;
    final pkCount = info.where((r) => r.read<int>('pk') > 0).length;
    final hasTissue = info.any((r) => r.read<String>('name') == 'tissue_id');
    if (hasTissue && pkCount >= 3) return;

    await customStatement('''
      CREATE TABLE check_in_pain_region_new (
        check_in_id TEXT NOT NULL REFERENCES check_in(id) ON DELETE CASCADE,
        region_id TEXT NOT NULL,
        tissue_id TEXT NOT NULL DEFAULT 'muscle',
        PRIMARY KEY (check_in_id, region_id, tissue_id)
      )
    ''');
    if (hasTissue) {
      await customStatement(
        "INSERT INTO check_in_pain_region_new (check_in_id, region_id, tissue_id) "
        "SELECT check_in_id, region_id, COALESCE(tissue_id, 'muscle') FROM check_in_pain_region",
      );
    } else {
      await customStatement(
        "INSERT INTO check_in_pain_region_new (check_in_id, region_id, tissue_id) "
        "SELECT check_in_id, region_id, 'muscle' FROM check_in_pain_region",
      );
    }
    await customStatement('DROP TABLE check_in_pain_region');
    await customStatement('ALTER TABLE check_in_pain_region_new RENAME TO check_in_pain_region');
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

/// Cache schema — deliberately separate from [_phiSchema].
///
/// Nothing here is PHI, nothing here participates in backup, and dropping the
/// whole table is always safe: every row can be re-fetched. It shares the
/// encrypted database only to reuse the one connection and the one key.
///
/// `cache_entry` must NEVER appear in `SnapshotService._tables`.
const _cacheSchema = <String>[
  '''
  CREATE TABLE IF NOT EXISTS cache_entry (
    namespace  TEXT    NOT NULL,
    key        TEXT    NOT NULL,
    payload    TEXT    NOT NULL,
    fetched_at INTEGER NOT NULL,
    PRIMARY KEY (namespace, key)
  )''',
  'CREATE INDEX IF NOT EXISTS idx_cache_entry_ns_time ON cache_entry(namespace, fetched_at)',
];

/// Map-pack download state — deliberately separate from [_phiSchema] and
/// [_cacheSchema]: not PHI, not a TTL cache (rows are written once per
/// verified download, not per fetch), and every row/file is safely
/// re-downloadable from the CDN. Must never appear in
/// `SnapshotService._tables`, same rule as `cache_entry`.
const _mapPacksSchema = <String>[
  '''
  CREATE TABLE IF NOT EXISTS map_pack_download (
    governorate_id TEXT    NOT NULL,
    kind           TEXT    NOT NULL,
    version        TEXT    NOT NULL,
    sha256         TEXT    NOT NULL,
    size_bytes     INTEGER NOT NULL,
    local_path     TEXT    NOT NULL,
    downloaded_at  INTEGER NOT NULL,
    PRIMARY KEY (governorate_id, kind)
  )''',
  '''
  CREATE TABLE IF NOT EXISTS map_pack_name (
    governorate_id TEXT NOT NULL,
    lang           TEXT NOT NULL,
    name           TEXT NOT NULL,
    PRIMARY KEY (governorate_id, lang)
  )''',
];

/// On-device PHI schema (matches the raw SQL in profile/medications DAOs).
/// All `IF NOT EXISTS` so `beforeOpen` is idempotent.
const _phiSchema = <String>[
  '''
  CREATE TABLE IF NOT EXISTS health_profile (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    blood_type TEXT,
    weight_kg REAL,
    height_cm REAL,
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
  // Care team (profile module). PHI, on-device only, partitioned by
  // health_profile_id. Patient-entered: there is no provider directory to link
  // against, so every field is free text and nothing is ever seeded — the
  // design prototype's sample doctors deliberately do not cross over.
  '''
  CREATE TABLE IF NOT EXISTS care_provider (
    id TEXT PRIMARY KEY,
    health_profile_id TEXT NOT NULL REFERENCES health_profile(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    name TEXT NOT NULL,
    specialty TEXT,
    phone TEXT,
    phone2 TEXT,
    email TEXT,
    clinic TEXT,
    address TEXT,
    map_url TEXT,
    notes TEXT,
    created_at INTEGER NOT NULL
  )''',
  'CREATE INDEX IF NOT EXISTS idx_care_provider_profile ON care_provider(health_profile_id)',
  // A provider's business card and files (attachments.jsx AttachmentGallery).
  // `path` is vault-relative — the bytes live encrypted in the user file store,
  // never in the database and never in plaintext on disk.
  '''
  CREATE TABLE IF NOT EXISTS care_provider_file (
    id TEXT PRIMARY KEY,
    care_provider_id TEXT NOT NULL REFERENCES care_provider(id) ON DELETE CASCADE,
    path TEXT NOT NULL,
    created_at INTEGER NOT NULL
  )''',
  'CREATE INDEX IF NOT EXISTS idx_care_provider_file_provider ON care_provider_file(care_provider_id)',
  // Durable push queue for cloud sync (FR-506). Generic by column shape so later
  // entities can reuse it; today only care_provider enqueues here. The payload is
  // a JSON copy of a PHI row, so this table lives in the SQLCipher database like
  // every other table here and is never logged.
  '''
  CREATE TABLE IF NOT EXISTS sync_outbox (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    entity TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    op TEXT NOT NULL,
    payload TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    attempts INTEGER NOT NULL DEFAULT 0,
    last_error TEXT
  )''',
  'CREATE INDEX IF NOT EXISTS idx_sync_outbox_entity ON sync_outbox(entity, id)',
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
  // NOTE: the medications/health_record profile-anchor indexes are created in
  // `beforeOpen` AFTER `_ensureColumn`, not here — on a pre-existing DB the
  // column doesn't exist yet when `_phiSchema` runs.
  // Appointments (appointments module). PHI, on-device only. Patient-entered:
  // there is no provider directory to link against, so the clinician is stored
  // as free text rather than a foreign key.
  '''
  CREATE TABLE IF NOT EXISTS appointment (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    clinician TEXT NOT NULL,
    specialty TEXT,
    location TEXT,
    kind TEXT NOT NULL,
    starts_at TEXT NOT NULL,
    created_at TEXT NOT NULL
  )''',
  'CREATE INDEX IF NOT EXISTS idx_appointment_user_time ON appointment(user_id, starts_at)',
  // Prescriptions (prescriptions module). PHI, on-device only. Patient-entered
  // from a paper/e-script: `items` is a JSON list of {name, dose}, and
  // `reference` is the code a pharmacy scans.
  '''
  CREATE TABLE IF NOT EXISTS prescription (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    clinician TEXT NOT NULL,
    specialty TEXT,
    reference TEXT,
    items TEXT NOT NULL,
    issued_at TEXT NOT NULL,
    valid_until TEXT,
    created_at TEXT NOT NULL
  )''',
  'CREATE INDEX IF NOT EXISTS idx_prescription_user_time ON prescription(user_id, issued_at)',
  // Self-report / check-in (self_report module). PHI, on-device only,
  // partitioned by health_profile_id (the person). Vitals are nullable
  // columns; symptoms and pain regions are child rows.
  '''
  CREATE TABLE IF NOT EXISTS check_in (
    id TEXT PRIMARY KEY,
    health_profile_id TEXT NOT NULL,
    recorded_at TEXT NOT NULL,
    mood INTEGER NOT NULL,
    pain_level INTEGER NOT NULL DEFAULT 0,
    note TEXT,
    photo_record_id TEXT,
    systolic INTEGER,
    diastolic INTEGER,
    heart_rate INTEGER,
    temperature REAL,
    weight_kg REAL,
    spo2 INTEGER,
    glucose_fasting INTEGER,
    glucose_post_meal INTEGER,
    glucose_random INTEGER
  )''',
  // `urine_color` / `urine_ml` / `blood` are the patient's own observations
  // (quicklog.jsx QuickSymptomDetail) — recorded verbatim, never interpreted.
  '''
  CREATE TABLE IF NOT EXISTS check_in_symptom (
    check_in_id TEXT NOT NULL REFERENCES check_in(id) ON DELETE CASCADE,
    symptom_id TEXT NOT NULL,
    urine_color TEXT,
    urine_ml INTEGER,
    blood INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (check_in_id, symptom_id)
  )''',
  '''
  CREATE TABLE IF NOT EXISTS check_in_pain_region (
    check_in_id TEXT NOT NULL REFERENCES check_in(id) ON DELETE CASCADE,
    region_id TEXT NOT NULL,
    tissue_id TEXT NOT NULL DEFAULT 'muscle',
    PRIMARY KEY (check_in_id, region_id, tissue_id)
  )''',
  'CREATE INDEX IF NOT EXISTS idx_check_in_profile ON check_in(health_profile_id)',
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
