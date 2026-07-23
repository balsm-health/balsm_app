import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The PHI schema + column patches + convergent backfill all run in
  // `beforeOpen`, which drift triggers on the first statement.
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

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
