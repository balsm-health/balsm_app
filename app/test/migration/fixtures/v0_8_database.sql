-- A Balsm v0.8.0+29 on-device database (origin/main 72c5f6b0), written by
-- v0.8's own data sources and dumped with `sqlite3 .dump`. All data synthetic.
-- PRAGMA user_version was 1 (drift schemaVersion).
PRAGMA foreign_keys=OFF;
BEGIN TRANSACTION;
CREATE TABLE health_profile (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    blood_type TEXT,
    weight_kg REAL,
    height_cm REAL,
    updated_at TEXT NOT NULL
  );
INSERT INTO health_profile VALUES('01a200dd-28ee-7a6c-827c-132ca2a98552','user-a','O+',70.0,170.0,'1795310823668');
INSERT INTO health_profile VALUES('01a200dd-28fd-714c-93b0-eb149f9f49d8','user-b',NULL,NULL,NULL,'1795310823678');
CREATE TABLE allergy (
    id TEXT PRIMARY KEY,
    health_profile_id TEXT NOT NULL REFERENCES health_profile(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    severity TEXT NOT NULL,
    is_controlled_substance INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL
  );
INSERT INTO allergy VALUES('alg-1','01a200dd-28ee-7a6c-827c-132ca2a98552','Test allergy','mild',0,'1795310823676');
CREATE TABLE chronic_condition (
    id TEXT PRIMARY KEY,
    health_profile_id TEXT NOT NULL REFERENCES health_profile(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    icd10_code TEXT,
    onset_year INTEGER,
    created_at TEXT NOT NULL
  );
INSERT INTO chronic_condition VALUES('cond-1','01a200dd-28ee-7a6c-827c-132ca2a98552','Test condition',NULL,NULL,'1795310823677');
CREATE TABLE emergency_contact (
    id TEXT PRIMARY KEY,
    health_profile_id TEXT NOT NULL REFERENCES health_profile(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    phone TEXT NOT NULL,
    relation TEXT,
    is_primary INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL
  );
INSERT INTO emergency_contact VALUES('ec-1','01a200dd-28ee-7a6c-827c-132ca2a98552','Test contact','+10000000000','friend',1,'1795310823677');
CREATE TABLE care_provider (
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
  , updated_at INTEGER, deleted_at INTEGER);
CREATE TABLE care_provider_file (
    id TEXT PRIMARY KEY,
    care_provider_id TEXT NOT NULL REFERENCES care_provider(id) ON DELETE CASCADE,
    path TEXT NOT NULL,
    kind TEXT NOT NULL DEFAULT 'file',
    created_at INTEGER NOT NULL
  );
CREATE TABLE sync_outbox (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    entity TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    op TEXT NOT NULL,
    payload TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    attempts INTEGER NOT NULL DEFAULT 0,
    last_error TEXT,
    user_id TEXT
  );
CREATE TABLE sync_cursor (
    entity TEXT NOT NULL,
    scope TEXT NOT NULL,
    value TEXT NOT NULL,
    PRIMARY KEY (entity, scope)
  );
CREATE TABLE medications (
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
  );
INSERT INTO medications VALUES('med-1','user-a','01a200dd-28ee-7a6c-827c-132ca2a98552','Test medicine',NULL,'daily','{"times":["08:00"]}','2026-04-01T00:00:00.000Z',NULL,0,NULL);
INSERT INTO medications VALUES('med-legacy','user-a',NULL,'Test medicine',NULL,'daily','{"times":["08:00"]}','2026-04-01T00:00:00.000Z',NULL,0,NULL);
CREATE TABLE dose_events (
    id TEXT PRIMARY KEY,
    medication_id TEXT NOT NULL REFERENCES medications(id),
    scheduled_at TEXT NOT NULL,
    recorded_at TEXT NOT NULL,
    outcome TEXT NOT NULL,
    parent_event_id TEXT,
    snooze_until TEXT
  );
INSERT INTO dose_events VALUES('dose-1','med-1','2026-04-02T08:00:00.000Z','2026-04-02T08:05:00.000Z','taken',NULL,NULL);
CREATE TABLE health_record (
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
  );
INSERT INTO health_record VALUES('rec-early','user-a','01a200dd-28ee-7a6c-827c-132ca2a98552','lab','Test record early','["t1"]','self',NULL,NULL,NULL,NULL,'2026-01-02T00:00:00.000Z','2026-01-02T00:00:00.000Z');
INSERT INTO health_record VALUES('rec-1','user-a','01a200dd-28ee-7a6c-827c-132ca2a98552','scan','Test record one','["t2"]','self',NULL,NULL,NULL,NULL,'2026-03-04T00:00:00.000Z','2026-03-04T00:00:00.000Z');
INSERT INTO health_record VALUES('rec-b','user-b','01a200dd-28fd-714c-93b0-eb149f9f49d8','lab','Test record other account','[]','self',NULL,NULL,NULL,NULL,'2026-05-01T00:00:00.000Z','2026-05-01T00:00:00.000Z');
CREATE TABLE appointment (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    clinician TEXT NOT NULL,
    specialty TEXT,
    location TEXT,
    kind TEXT NOT NULL,
    starts_at TEXT NOT NULL,
    created_at TEXT NOT NULL
  );
CREATE TABLE prescription (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    clinician TEXT NOT NULL,
    specialty TEXT,
    reference TEXT,
    items TEXT NOT NULL,
    issued_at TEXT NOT NULL,
    valid_until TEXT,
    created_at TEXT NOT NULL
  , title TEXT, source TEXT, attachment_path TEXT, attachment_kind TEXT);
INSERT INTO prescription VALUES('rx-1','user-a','Test clinician',NULL,NULL,'[{"name":"Test item","dose":"1 unit"}]','2026-04-01T00:00:00.000Z',NULL,'2026-04-01T00:00:00.000Z',NULL,NULL,NULL,NULL);
INSERT INTO prescription VALUES('rx-b','user-b','Test clinician B',NULL,NULL,'[]','2026-05-01T00:00:00.000Z',NULL,'2026-05-01T00:00:00.000Z',NULL,NULL,NULL,NULL);
CREATE TABLE check_in (
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
  );
INSERT INTO check_in VALUES('chk-1','01a200dd-28ee-7a6c-827c-132ca2a98552','2026-04-03T09:00:00.000Z',4,3,NULL,NULL,120,80,NULL,NULL,NULL,NULL,90,NULL,NULL);
CREATE TABLE check_in_symptom (
    check_in_id TEXT NOT NULL REFERENCES check_in(id) ON DELETE CASCADE,
    symptom_id TEXT NOT NULL,
    urine_color TEXT,
    urine_ml INTEGER,
    blood INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (check_in_id, symptom_id)
  );
INSERT INTO check_in_symptom VALUES('chk-1','headache',NULL,NULL,0);
CREATE TABLE check_in_pain_region (
    check_in_id TEXT NOT NULL REFERENCES check_in(id) ON DELETE CASCADE,
    region_id TEXT NOT NULL,
    tissue_id TEXT NOT NULL DEFAULT 'muscle',
    PRIMARY KEY (check_in_id, region_id, tissue_id)
  );
INSERT INTO check_in_pain_region VALUES('chk-1','chest','muscle');
CREATE TABLE disclosure_acceptance (
    id TEXT PRIMARY KEY,
    disclosure_id TEXT NOT NULL,
    version TEXT NOT NULL,
    country_code TEXT NOT NULL,
    supervisory_authority_name TEXT NOT NULL,
    preferred_language TEXT NOT NULL,
    accepted_at INTEGER NOT NULL,
    UNIQUE(disclosure_id, version)
  );
CREATE TABLE cache_entry (
    namespace  TEXT    NOT NULL,
    key        TEXT    NOT NULL,
    payload    TEXT    NOT NULL,
    fetched_at INTEGER NOT NULL,
    PRIMARY KEY (namespace, key)
  );
CREATE TABLE map_pack_download (
    governorate_id TEXT    NOT NULL,
    kind           TEXT    NOT NULL,
    version        TEXT    NOT NULL,
    sha256         TEXT    NOT NULL,
    size_bytes     INTEGER NOT NULL,
    local_path     TEXT    NOT NULL,
    downloaded_at  INTEGER NOT NULL,
    PRIMARY KEY (governorate_id, kind)
  );
CREATE TABLE map_pack_name (
    governorate_id TEXT NOT NULL,
    lang           TEXT NOT NULL,
    name           TEXT NOT NULL,
    PRIMARY KEY (governorate_id, lang)
  );
CREATE TRIGGER dose_events_no_update
  BEFORE UPDATE ON dose_events
  BEGIN SELECT RAISE(ABORT, 'dose_events is append-only'); END;
CREATE TRIGGER dose_events_no_delete
  BEFORE DELETE ON dose_events
  BEGIN SELECT RAISE(ABORT, 'dose_events is append-only'); END;
CREATE INDEX idx_care_provider_profile ON care_provider(health_profile_id);
CREATE INDEX idx_care_provider_file_provider ON care_provider_file(care_provider_id);
CREATE INDEX idx_sync_outbox_entity ON sync_outbox(entity, id);
CREATE INDEX idx_appointment_user_time ON appointment(user_id, starts_at);
CREATE INDEX idx_prescription_user_time ON prescription(user_id, issued_at);
CREATE INDEX idx_check_in_profile ON check_in(health_profile_id);
CREATE INDEX idx_cache_entry_ns_time ON cache_entry(namespace, fetched_at);
CREATE INDEX idx_medications_profile ON medications(health_profile_id);
CREATE INDEX idx_health_record_profile ON health_record(health_profile_id);
CREATE INDEX idx_sync_outbox_user ON sync_outbox(user_id, id);
COMMIT;
