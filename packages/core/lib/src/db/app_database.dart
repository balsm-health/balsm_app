import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/value_objects/health_profile_id.dart';
import '../domain/value_objects/user_id.dart';
// Conditional executor: SQLCipher (dart:ffi) on device, encrypted WASM SQLite on web.
import 'database_connection_io.dart' if (dart.library.js_interop) 'database_connection_web.dart';

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
          // below fills it as profile rows appear. Every one of these tables
          // is read by health_profile_id (the person), not user_id.
          await _ensureColumn('medications', 'health_profile_id', 'TEXT');
          await _ensureColumn('health_record', 'health_profile_id', 'TEXT');
          await _ensureColumn('prescription', 'health_profile_id', 'TEXT');
          await _ensureColumn('prescription', 'title', 'TEXT');
          await _ensureColumn('prescription', 'source', 'TEXT');
          await _ensureColumn('prescription', 'attachment_path', 'TEXT');
          await _ensureColumn('prescription', 'attachment_kind', 'TEXT');
          await _ensureColumn('check_in_symptom', 'urine_color', 'TEXT');
          await _ensureColumn('check_in_symptom', 'urine_ml', 'INTEGER');
          await _ensureColumn('medications', 'notes', 'TEXT');
          await _ensureColumn('check_in_symptom', 'blood', 'INTEGER NOT NULL DEFAULT 0');
          await _ensureColumn('care_provider', 'map_url', 'TEXT');
          // Pre-existing attachment rows are all vault files, which is exactly
          // what the default backfills.
          await _ensureColumn('care_provider_file', 'kind', "TEXT NOT NULL DEFAULT 'file'");
          // Cloud-sync bookkeeping (FR-507/FR-508). Nullable so pre-existing rows
          // migrate without a backfill; the sync service treats a null updated_at
          // as created_at.
          await _ensureColumn('care_provider', 'updated_at', 'INTEGER');
          await _ensureColumn('care_provider', 'deleted_at', 'INTEGER');
          // Queue predates user scoping: entries with a null user_id belong to
          // whoever was signed in before the upgrade and are never drained.
          await _ensureColumn('sync_outbox', 'user_id', 'TEXT');
          await _ensurePainSitePk();
          await _ensureMultiProfileColumns();
          // These indexes must be created AFTER the column patches above — on a
          // pre-existing DB the `medications`/`health_record` tables predate
          // `health_profile_id`, so indexing it inside `_phiSchema` (which runs
          // before the patches) would fail with "no such column".
          await customStatement('CREATE INDEX IF NOT EXISTS idx_medications_profile ON medications(health_profile_id)');
          await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_health_record_profile ON health_record(health_profile_id)');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_sync_outbox_user ON sync_outbox(user_id, id)');
          await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_prescription_profile ON prescription(health_profile_id, issued_at)');
          await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_health_profile_user ON health_profile(user_id, is_self)');
          await runProfileAnchorBackfill();
        },
      );

  /// Idempotently adds [column] (with SQL [ddlType]) to [table] when it is not
  /// already present. Evolves the raw-SQL PHI schema (see [_phiSchema]) without
  /// a full drift migration; safe to run on every open. Returns true when the
  /// column was added on this open, so a one-time backfill can key off it.
  Future<bool> _ensureColumn(String table, String column, String ddlType) async {
    final info = await customSelect('PRAGMA table_info($table)').get();
    final hasColumn = info.any((r) => r.read<String>('name') == column);
    if (!hasColumn) {
      await customStatement('ALTER TABLE $table ADD COLUMN $column $ddlType');
    }
    return !hasColumn;
  }

  /// Family-member columns on `health_profile` (Mother & Child, stage 1).
  ///
  /// Before these, every row was its account's self profile. When `is_self`
  /// arrives on an existing DB the backfill marks the account's earliest row
  /// self (and kind `self`); any later row of the same account — which only a
  /// past merge could have left — becomes a dependent rather than a second
  /// self. Runs once: on later opens the column exists and nothing changes,
  /// so a real dependent is never promoted.
  Future<void> _ensureMultiProfileColumns() async {
    final addedIsSelf = await _ensureColumn('health_profile', 'is_self', 'INTEGER NOT NULL DEFAULT 0');
    await _ensureColumn('health_profile', 'kind', "TEXT NOT NULL DEFAULT 'self'");
    await _ensureColumn('health_profile', 'display_name', 'TEXT');
    await _ensureColumn('health_profile', 'date_of_birth', 'TEXT');
    await _ensureColumn('health_profile', 'sex', 'TEXT');
    await _ensureColumn('health_profile', 'relationship', 'TEXT');
    await _ensureColumn('health_profile', 'group_id', 'TEXT');
    await _ensureColumn('health_profile', 'tone', 'TEXT');
    await _ensureColumn('health_profile', 'status', "TEXT NOT NULL DEFAULT 'active'");
    await _ensureColumn('health_profile', 'closed_on', 'TEXT');
    await _ensureColumn('health_profile', 'pregnancy_id', 'TEXT');
    await _ensureColumn('health_profile', 'sequence', 'INTEGER');
    if (addedIsSelf) {
      await customStatement(
          'UPDATE health_profile SET is_self = 1 WHERE rowid IN (SELECT MIN(rowid) FROM health_profile GROUP BY user_id)');
      await customStatement("UPDATE health_profile SET kind = CASE WHEN is_self = 1 THEN 'self' ELSE 'dependent' END");
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

  /// Anchors any NULL `health_profile_id` rows to their user's **self**
  /// profile row (convergent, idempotent). Rows written before profiles were
  /// per-person all belong to the account holder, so self is the only correct
  /// anchor — never "whichever profile the account has". Runs on every open
  /// and again after [ensureSelfHealthProfile] creates a profile row
  /// mid-session.
  Future<void> runProfileAnchorBackfill() async {
    for (final table in _profileAnchoredTables) {
      await customStatement('''
        UPDATE $table SET health_profile_id =
          (SELECT hp.id FROM health_profile hp
            WHERE hp.user_id = $table.user_id AND hp.is_self = 1
            ORDER BY hp.rowid LIMIT 1)
        WHERE health_profile_id IS NULL''');
    }
  }

  /// Tables that carry both the actor (`user_id`) and the subject
  /// (`health_profile_id`) and were anchored to a profile after they shipped.
  static const _profileAnchoredTables = ['medications', 'health_record', 'prescription'];

  /// [userId]'s self health-profile id (`is_self = 1`), or null when the row
  /// does not exist yet. The earliest such row wins, deterministically.
  Future<HealthProfileId?> selfHealthProfileId(UserId userId) async {
    final rows = await customSelect(
      'SELECT id FROM health_profile WHERE user_id = ? AND is_self = 1 ORDER BY rowid LIMIT 1',
      variables: [Variable.withString(userId.value)],
    ).get();
    return rows.isEmpty ? null : HealthProfileId.value(rows.first.read<String>('id'));
  }

  /// Returns [userId]'s self health-profile id, creating the (empty) row on
  /// first call — the guarantee behind `currentProfileIdProvider`: every
  /// signed-in session has a profile scope. Resolves by `is_self`, never by
  /// "the account's first row", so dependent profiles can't be mistaken for
  /// the account holder. Also re-runs the anchor backfill so rows written
  /// before the profile existed converge immediately.
  Future<HealthProfileId> ensureSelfHealthProfile(UserId userId) async {
    final existing = await selfHealthProfileId(userId);
    if (existing != null) return existing;
    final id = HealthProfileId.uuid();
    // updated_at is epoch-millis (matches the profile DAO's hydration).
    await customInsert(
      "INSERT INTO health_profile (id, user_id, is_self, kind, status, updated_at) VALUES (?, ?, 1, 'self', 'active', ?)",
      variables: [
        Variable.withString(id.value),
        Variable.withString(userId.value),
        Variable.withInt(DateTime.now().millisecondsSinceEpoch),
      ],
    );
    await runProfileAnchorBackfill();
    return id;
  }

  /// The profile [userId] has selected on this device, when it still exists,
  /// belongs to [userId] and is not closed; otherwise the self profile
  /// (created on first call). The one rule behind `activeProfileProvider`:
  /// a stale, foreign or closed selection always falls back to self.
  Future<HealthProfileId> resolveActiveHealthProfile(UserId userId) async {
    final self = await ensureSelfHealthProfile(userId);
    final rows = await customSelect(
      '''
      SELECT ap.health_profile_id AS id FROM active_profile ap
        JOIN health_profile hp ON hp.id = ap.health_profile_id AND hp.user_id = ap.user_id
      WHERE ap.user_id = ? AND hp.status = 'active'
      ORDER BY ap.selected_at DESC LIMIT 1''',
      variables: [Variable.withString(userId.value)],
    ).get();
    return rows.isEmpty ? self : HealthProfileId.value(rows.first.read<String>('id'));
  }

  /// Records [profileId] as [userId]'s active profile on this device; null
  /// clears the selection (back to self). Returns false — and changes
  /// nothing — when [profileId] is not an active profile of [userId].
  Future<bool> setActiveHealthProfile(UserId userId, HealthProfileId? profileId) async {
    return transaction(() async {
      if (profileId != null) {
        final owned = await customSelect(
          "SELECT 1 FROM health_profile WHERE id = ? AND user_id = ? AND status = 'active'",
          variables: [Variable.withString(profileId.value), Variable.withString(userId.value)],
        ).get();
        if (owned.isEmpty) return false;
      }
      await customUpdate(
        'DELETE FROM active_profile WHERE user_id = ?',
        variables: [Variable.withString(userId.value)],
        updateKind: UpdateKind.delete,
      );
      if (profileId != null) {
        await customInsert(
          'INSERT INTO active_profile (user_id, health_profile_id, selected_at) VALUES (?, ?, ?)',
          variables: [
            Variable.withString(userId.value),
            Variable.withString(profileId.value),
            Variable.withInt(DateTime.now().millisecondsSinceEpoch),
          ],
        );
      }
      return true;
    });
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
    updated_at TEXT NOT NULL,
    is_self INTEGER NOT NULL DEFAULT 0,
    kind TEXT NOT NULL DEFAULT 'self',
    display_name TEXT,
    date_of_birth TEXT,
    sex TEXT,
    relationship TEXT,
    group_id TEXT,
    tone TEXT,
    status TEXT NOT NULL DEFAULT 'active',
    closed_on TEXT,
    pregnancy_id TEXT,
    sequence INTEGER
  )''',
  // The profile each account last selected on this device (the profile
  // switcher). Not PHI, but it names a PHI partition, so it lives in the
  // encrypted database and is re-keyed / merged / discarded with the owner's
  // rows by `owner_rekey.dart` like every other user_id table. No uniqueness
  // on user_id on purpose: a merge may briefly bring two rows, and the newest
  // (`selected_at`) wins. A dangling or closed selection resolves to self —
  // see `AppDatabase.resolveActiveHealthProfile`.
  '''
  CREATE TABLE IF NOT EXISTS active_profile (
    user_id TEXT NOT NULL,
    health_profile_id TEXT NOT NULL REFERENCES health_profile(id) ON DELETE CASCADE,
    selected_at INTEGER NOT NULL
  )''',
  'CREATE INDEX IF NOT EXISTS idx_active_profile_user ON active_profile(user_id, selected_at)',
  // Family groups ("My family", "Neighbours", user-added) the member profiles
  // are filed under (`health_profile.group_id`). Soft-delete only.
  '''
  CREATE TABLE IF NOT EXISTS member_group (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    name TEXT NOT NULL,
    sort INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL,
    deleted_at INTEGER
  )''',
  'CREATE INDEX IF NOT EXISTS idx_member_group_user ON member_group(user_id, sort)',
  // Vaccination log per person (Personal Health VaccinationRecord). Dates are
  // ISO calendar dates (YYYY-MM-DD). Soft-delete only.
  '''
  CREATE TABLE IF NOT EXISTS vaccination_record (
    id TEXT PRIMARY KEY,
    health_profile_id TEXT NOT NULL REFERENCES health_profile(id) ON DELETE CASCADE,
    vaccine TEXT NOT NULL,
    dose_number INTEGER,
    administered_on TEXT,
    clinic TEXT,
    next_due_on TEXT,
    created_at INTEGER NOT NULL,
    deleted_at INTEGER
  )''',
  'CREATE INDEX IF NOT EXISTS idx_vaccination_record_profile ON vaccination_record(health_profile_id)',
  // Growth log per person (weight/height over time). Soft-delete only.
  '''
  CREATE TABLE IF NOT EXISTS growth_entry (
    id TEXT PRIMARY KEY,
    health_profile_id TEXT NOT NULL REFERENCES health_profile(id) ON DELETE CASCADE,
    measured_on TEXT NOT NULL,
    weight_kg REAL,
    height_cm REAL,
    created_at INTEGER NOT NULL,
    deleted_at INTEGER
  )''',
  'CREATE INDEX IF NOT EXISTS idx_growth_entry_profile ON growth_entry(health_profile_id, measured_on)',
  // A pregnancy, owned by the mother's profile. `status`: active | birth |
  // ended. Baby (prenatal) profiles point back via `health_profile.pregnancy_id`.
  '''
  CREATE TABLE IF NOT EXISTS pregnancy (
    id TEXT PRIMARY KEY,
    health_profile_id TEXT NOT NULL REFERENCES health_profile(id) ON DELETE CASCADE,
    due_date TEXT,
    ob_name TEXT,
    ob_phone TEXT,
    next_visit_on TEXT,
    next_visit_time TEXT,
    next_visit_clinic TEXT,
    status TEXT NOT NULL DEFAULT 'active',
    closed_on TEXT,
    created_at INTEGER NOT NULL,
    deleted_at INTEGER
  )''',
  'CREATE INDEX IF NOT EXISTS idx_pregnancy_profile ON pregnancy(health_profile_id)',
  // Something recorded during a pregnancy. `about`: me | baby; `kind`: scan |
  // measure | doc. `attachment_ref` is a vault-relative locator (bytes live
  // encrypted in the user file store, never here). Soft-delete only.
  '''
  CREATE TABLE IF NOT EXISTS pregnancy_item (
    id TEXT PRIMARY KEY,
    pregnancy_id TEXT NOT NULL REFERENCES pregnancy(id) ON DELETE CASCADE,
    about TEXT NOT NULL,
    kind TEXT NOT NULL,
    title TEXT,
    recorded_on TEXT NOT NULL,
    fetal_hr_bpm INTEGER,
    efw_g INTEGER,
    other_label TEXT,
    other_value TEXT,
    attachment_ref TEXT,
    created_at INTEGER NOT NULL,
    deleted_at INTEGER
  )''',
  'CREATE INDEX IF NOT EXISTS idx_pregnancy_item_pregnancy ON pregnancy_item(pregnancy_id, recorded_on)',
  // Which baby (prenatal / born profile) a pregnancy item is about. Birth keeps
  // the baby's profile id, so these links carry the item into the child's
  // history; "records that move" detaches unticked items by soft-deleting the
  // link — the item itself stays on the pregnancy.
  '''
  CREATE TABLE IF NOT EXISTS pregnancy_item_baby (
    item_id TEXT NOT NULL REFERENCES pregnancy_item(id) ON DELETE CASCADE,
    health_profile_id TEXT NOT NULL REFERENCES health_profile(id) ON DELETE CASCADE,
    deleted_at INTEGER,
    PRIMARY KEY (item_id, health_profile_id)
  )''',
  'CREATE INDEX IF NOT EXISTS idx_pregnancy_item_baby_profile ON pregnancy_item_baby(health_profile_id)',
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
  //
  // `path` is the locator and `kind` says how to read it:
  //   'file' — vault-relative; the bytes live encrypted in the user file store,
  //            never in the database and never in plaintext on disk.
  //   'link' — an absolute http(s) URL the patient pasted. Nothing is fetched;
  //            it is opened externally on tap.
  //
  // One column rather than a second nullable `url`: `path` is NOT NULL and
  // SQLite cannot drop that, so a link row would have had to carry a dummy
  // path. A discriminator keeps every row honest about what it holds.
  '''
  CREATE TABLE IF NOT EXISTS care_provider_file (
    id TEXT PRIMARY KEY,
    care_provider_id TEXT NOT NULL REFERENCES care_provider(id) ON DELETE CASCADE,
    path TEXT NOT NULL,
    kind TEXT NOT NULL DEFAULT 'file',
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
    last_error TEXT,
    user_id TEXT
  )''',
  'CREATE INDEX IF NOT EXISTS idx_sync_outbox_entity ON sync_outbox(entity, id)',
  // idx_sync_outbox_user is NOT here: user_id was added to this table after it
  // shipped, so on an existing device the CREATE TABLE above is a no-op and the
  // column only appears in the patch block. See the index note in `beforeOpen`.
  // Incremental-pull cursor per (entity, scope). Deliberately in the PHI database
  // rather than SharedPreferences: the cursor is derived from PHI timestamps and
  // must be wiped with the rows it describes. A cursor that outlived a local wipe
  // would make the next pull skip every row the device no longer has.
  '''
  CREATE TABLE IF NOT EXISTS sync_cursor (
    entity TEXT NOT NULL,
    scope TEXT NOT NULL,
    value TEXT NOT NULL,
    PRIMARY KEY (entity, scope)
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
    is_controlled INTEGER NOT NULL DEFAULT 0,
    notes TEXT
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
    health_profile_id TEXT,
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
