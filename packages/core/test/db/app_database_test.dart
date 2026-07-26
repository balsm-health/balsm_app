import 'dart:io';

import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  // The PHI schema + column patches + convergent backfill all run in
  // `beforeOpen`, which drift triggers on the first statement.
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('opens a legacy DB whose medications table predates health_profile_id',
      () async {
    // Reproduces the crash: a pre-existing file DB with the OLD medications
    // schema (no health_profile_id). beforeOpen must ADD the column before
    // indexing it — indexing a missing column raised "no such column".
    final dir = await Directory.systemTemp.createTemp('balsm_legacy_db');
    final file = File('${dir.path}/legacy.db');
    addTearDown(() => dir.delete(recursive: true));

    // Seed the legacy table with a raw sqlite3 connection, then close it.
    final seed = sqlite3.open(file.path);
    seed.execute(
      'CREATE TABLE medications (id TEXT PRIMARY KEY, user_id TEXT NOT NULL, '
      'name TEXT NOT NULL, schedule_type TEXT NOT NULL, '
      'schedule_config TEXT NOT NULL, start_date TEXT NOT NULL)',
    );
    seed.dispose();

    // Opening AppDatabase over the legacy file must not throw.
    final legacy = AppDatabase(NativeDatabase(file));
    addTearDown(legacy.close);
    final cols = await legacy.customSelect('PRAGMA table_info(medications)').get();
    expect(cols.map((r) => r.read<String>('name')), contains('health_profile_id'));
    final idx = await legacy
        .customSelect(
            "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_medications_profile'")
        .get();
    expect(idx, isNotEmpty, reason: 'index created after the column patch');
  });

  test('PHI schema creates the profile-anchor columns and indexes', () async {
    for (final table in ['medications', 'health_record']) {
      final cols = await db.customSelect('PRAGMA table_info($table)').get();
      expect(cols.map((r) => r.read<String>('name')),
          contains('health_profile_id'),
          reason: '$table must carry the dependants profile anchor');
    }
    final idx = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
        .get();
    final names = idx.map((r) => r.read<String>('name')).toList();
    expect(names, contains('idx_medications_profile'));
    expect(names, contains('idx_health_record_profile'));
  });

  test('insert before any profile row stores NULL, not a wrong anchor',
      () async {
    // A medication written BEFORE any health_profile row (lazy creation) —
    // the subselect resolves to NULL; the convergent backfill fixes it later.
    await db.customStatement('''
      INSERT INTO medications (id, user_id, health_profile_id, name,
        schedule_type, schedule_config, start_date)
      VALUES ('m1', 'u1',
        (SELECT id FROM health_profile WHERE user_id = 'u1'),
        'Glipizide', 'daily', '{}', '2026-01-01')''');
    final row = await db
        .customSelect('SELECT health_profile_id FROM medications').getSingle();
    expect(row.readNullable<String>('health_profile_id'), isNull);
  });

  test('inserts anchor immediately when the profile row already exists',
      () async {
    await db.customStatement('''
      INSERT INTO health_profile (id, user_id, updated_at)
      VALUES ('hp1', 'u1', '2026-01-01')''');
    await db.customStatement('''
      INSERT INTO medications (id, user_id, health_profile_id, name,
        schedule_type, schedule_config, start_date)
      VALUES ('m1', 'u1',
        (SELECT id FROM health_profile WHERE user_id = 'u1'),
        'Glipizide', 'daily', '{}', '2026-01-01')''');
    final row = await db
        .customSelect('SELECT health_profile_id FROM medications').getSingle();
    expect(row.read<String>('health_profile_id'), 'hp1');
  });

  test(
      'ensureSelfHealthProfile creates once, is idempotent, and anchors '
      'orphan rows immediately', () async {
    // Orphan row written before any profile existed.
    await db.customStatement('''
      INSERT INTO medications (id, user_id, health_profile_id, name,
        schedule_type, schedule_config, start_date)
      VALUES ('m1', 'u1', NULL, 'A', 'daily', '{}', 't')''');

    final id = await db.ensureSelfHealthProfile(UserId.value('u1'));
    expect(id.value, isNotEmpty);

    // Idempotent — same id on every later call, no duplicate rows.
    final again = await db.ensureSelfHealthProfile(UserId.value('u1'));
    expect(again.value, id.value);
    final rows = await db
        .customSelect("SELECT id FROM health_profile WHERE user_id = 'u1'")
        .get();
    expect(rows.length, 1);

    // The orphan medication got anchored by the post-ensure backfill.
    final med = await db
        .customSelect('SELECT health_profile_id FROM medications').getSingle();
    expect(med.read<String>('health_profile_id'), id.value);

    // The row hydrates through the profile DAO shape (updated_at is int).
    final hp = await db
        .customSelect('SELECT updated_at FROM health_profile').getSingle();
    expect(hp.read<int>('updated_at'), isA<int>());
  });

  test('backfill statement anchors NULL rows and never overwrites', () async {
    await db.customStatement(
        "INSERT INTO health_profile (id, user_id, updated_at) VALUES ('hp1','u1','t')");
    await db.customStatement('''
      INSERT INTO medications (id, user_id, health_profile_id, name,
        schedule_type, schedule_config, start_date)
      VALUES ('m1', 'u1', NULL, 'A', 'daily', '{}', 't'),
             ('m2', 'u1', 'hp-existing', 'B', 'daily', '{}', 't')''');
    // Byte-identical to the convergent backfill in AppDatabase.beforeOpen.
    await db.customStatement('''
      UPDATE medications SET health_profile_id =
        (SELECT hp.id FROM health_profile hp
          WHERE hp.user_id = medications.user_id)
      WHERE health_profile_id IS NULL''');
    final rows = await db
        .customSelect(
            'SELECT id, health_profile_id FROM medications ORDER BY id')
        .get();
    expect(rows[0].read<String>('health_profile_id'), 'hp1');
    expect(rows[1].read<String>('health_profile_id'), 'hp-existing');
  });
}
