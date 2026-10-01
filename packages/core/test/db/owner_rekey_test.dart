import 'package:core/core.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _Db extends GeneratedDatabase {
  _Db() : super(NativeDatabase.memory());
  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];
  @override
  int get schemaVersion => 1;
}

Future<_Db> _seed() async {
  final db = _Db();
  await db.customStatement('CREATE TABLE health_profile (id TEXT, user_id TEXT)');
  await db.customStatement('CREATE TABLE prescription (id TEXT, user_id TEXT)');
  await db.customStatement('CREATE TABLE sync_outbox (id INTEGER PRIMARY KEY, user_id TEXT)');
  await db.customStatement('CREATE TABLE lookup (id TEXT)'); // no user_id: untouched
  await db.customStatement("INSERT INTO health_profile VALUES ('p1','off'), ('p2','other')");
  await db.customStatement("INSERT INTO prescription VALUES ('r1','off')");
  await db.customStatement("INSERT INTO sync_outbox (user_id) VALUES ('off'), ('other')");
  await db.customStatement("INSERT INTO lookup VALUES ('x')");
  return db;
}

Future<List<String?>> _owners(_Db db, String table) async =>
    (await db.customSelect('SELECT user_id FROM $table ORDER BY rowid').get())
        .map((r) => r.read<String?>('user_id'))
        .toList();

void main() {
  main2();

  test('re-keys every user_id table, only the matching rows', () async {
    final db = await _seed();
    await rekeyOwner(db, from: 'off', to: 'srv', dropOutbox: false);
    expect(await _owners(db, 'health_profile'), ['srv', 'other']);
    expect(await _owners(db, 'prescription'), ['srv']);
    expect(await _owners(db, 'sync_outbox'), ['srv', 'other']);
  });

  test('merge drops the retired account\'s outbox rows', () async {
    final db = await _seed();
    await rekeyOwner(db, from: 'off', to: 'srv', dropOutbox: true);
    expect(await _owners(db, 'sync_outbox'), ['other']);
    expect(await _owners(db, 'prescription'), ['srv']);
  });

  test('all-or-nothing: a failure rolls every table back', () async {
    final db = await _seed();
    await db
        .customStatement("CREATE TRIGGER boom BEFORE UPDATE ON prescription BEGIN SELECT RAISE(ABORT, 'boom'); END");
    await expectLater(rekeyOwner(db, from: 'off', to: 'srv', dropOutbox: false), throwsA(anything));
    expect(await _owners(db, 'health_profile'), ['off', 'other']);
  });

  test('same id is a no-op', () async {
    final db = await _seed();
    expect(await rekeyOwner(db, from: 'off', to: 'off', dropOutbox: true), 0);
    expect(await _owners(db, 'sync_outbox'), ['off', 'other']);
  });
}

/// A closer copy of the real schema: profile children keyed by
/// `health_profile_id`, a grandchild with a non-cascading foreign key, and
/// foreign keys enforced as the app database does.
Future<_Db> _seedProfiles({required bool targetHasProfile}) async {
  final db = _Db();
  await db.customStatement('PRAGMA foreign_keys = ON');
  await db.customStatement('CREATE TABLE health_profile (id TEXT PRIMARY KEY, user_id TEXT NOT NULL)');
  await db.customStatement('CREATE TABLE allergy (id TEXT PRIMARY KEY, '
      'health_profile_id TEXT NOT NULL REFERENCES health_profile(id) ON DELETE CASCADE)');
  await db.customStatement('CREATE TABLE medications (id TEXT PRIMARY KEY, user_id TEXT NOT NULL, '
      'health_profile_id TEXT NOT NULL REFERENCES health_profile(id) ON DELETE CASCADE)');
  await db.customStatement(
      'CREATE TABLE dose_events (id TEXT PRIMARY KEY, medication_id TEXT NOT NULL REFERENCES medications(id))');
  await db.customStatement('CREATE TABLE sync_outbox (id INTEGER PRIMARY KEY, user_id TEXT)');
  await db.customStatement("INSERT INTO health_profile VALUES ('p-off','off')");
  if (targetHasProfile) {
    await db.customStatement("INSERT INTO health_profile VALUES ('p-srv','srv')");
    await db.customStatement("INSERT INTO allergy VALUES ('a-srv','p-srv')");
  }
  await db.customStatement("INSERT INTO allergy VALUES ('a1','p-off'), ('a2','p-off')");
  await db.customStatement("INSERT INTO medications VALUES ('m1','off','p-off')");
  await db.customStatement("INSERT INTO dose_events VALUES ('d1','m1')");
  await db.customStatement("INSERT INTO sync_outbox (user_id) VALUES ('off'), ('srv')");
  return db;
}

Future<List<String>> _rows(_Db db, String sql) async =>
    (await db.customSelect(sql).get()).map((r) => r.data.values.map((v) => '$v').join('|')).toList();

void main2() {
  test('ownedTables lists every user_id table, and only those', () async {
    final db = await _seed();
    expect((await ownedTables(db))..sort(), ['health_profile', 'prescription', 'sync_outbox']);
  });

  group('mergeOwner', () {
    test('target already has a profile: children move to it, one self profile remains', () async {
      final db = await _seedProfiles(targetHasProfile: true);
      await mergeOwner(db, from: 'off', to: 'srv');
      expect(await _rows(db, 'SELECT id, user_id FROM health_profile'), ['p-srv|srv']);
      expect(await _rows(db, 'SELECT id, health_profile_id FROM allergy ORDER BY id'),
          ['a-srv|p-srv', 'a1|p-srv', 'a2|p-srv']);
      expect(await _rows(db, 'SELECT id, user_id, health_profile_id FROM medications'), ['m1|srv|p-srv']);
      expect(await _rows(db, 'SELECT id FROM dose_events'), ['d1']);
      expect(await _rows(db, 'SELECT user_id FROM sync_outbox'), ['srv']);
    });

    test('target has no profile: the offline profile moves over whole', () async {
      final db = await _seedProfiles(targetHasProfile: false);
      await mergeOwner(db, from: 'off', to: 'srv');
      expect(await _rows(db, 'SELECT id, user_id FROM health_profile'), ['p-off|srv']);
      expect(await _rows(db, 'SELECT health_profile_id FROM allergy ORDER BY id'), ['p-off', 'p-off']);
      expect(await _rows(db, 'SELECT user_id FROM medications'), ['srv']);
      expect(await _rows(db, 'SELECT user_id FROM sync_outbox'), ['srv']);
    });

    test('second run is a no-op', () async {
      final db = await _seedProfiles(targetHasProfile: true);
      await mergeOwner(db, from: 'off', to: 'srv');
      await mergeOwner(db, from: 'off', to: 'srv');
      expect(await _rows(db, 'SELECT id FROM health_profile'), ['p-srv']);
      expect(await _rows(db, 'SELECT id FROM allergy ORDER BY id'), ['a-srv', 'a1', 'a2']);
    });

    test('all-or-nothing: a failure leaves the profile and its children untouched', () async {
      final db = await _seedProfiles(targetHasProfile: true);
      // Profile consolidation runs first; the user_id re-key then fails.
      await db.customStatement('CREATE TABLE later (id TEXT, user_id TEXT)');
      await db.customStatement("INSERT INTO later VALUES ('x','off')");
      await db.customStatement("CREATE TRIGGER boom2 BEFORE UPDATE ON later BEGIN SELECT RAISE(ABORT, 'boom'); END");
      await expectLater(mergeOwner(db, from: 'off', to: 'srv'), throwsA(anything));
      expect(await _rows(db, 'SELECT id FROM health_profile ORDER BY id'), ['p-off', 'p-srv']);
      expect(await _rows(db, 'SELECT health_profile_id FROM allergy ORDER BY id'), ['p-srv', 'p-off', 'p-off']);
    });
  });

  group('discardOwner', () {
    test('deletes every row the owner has, down to grandchildren; others untouched', () async {
      final db = await _seedProfiles(targetHasProfile: true);
      await discardOwner(db, owner: 'off');
      expect(await _rows(db, 'SELECT id FROM health_profile'), ['p-srv']);
      expect(await _rows(db, 'SELECT id FROM allergy'), ['a-srv']);
      expect(await _rows(db, 'SELECT id FROM medications'), isEmpty);
      expect(await _rows(db, 'SELECT id FROM dose_events'), isEmpty);
      expect(await _rows(db, 'SELECT user_id FROM sync_outbox'), ['srv']);
    });

    test('any delete guard other than the approved dose-history one makes it throw, changing nothing', () async {
      final db = await _seedProfiles(targetHasProfile: false);
      await db.customStatement(
          "CREATE TRIGGER allergy_keep BEFORE DELETE ON allergy BEGIN SELECT RAISE(ABORT, 'kept'); END");
      await expectLater(discardOwner(db, owner: 'off'), throwsStateError);
      expect(await _rows(db, 'SELECT id FROM allergy ORDER BY id'), ['a1', 'a2']);
      expect(await _rows(db, 'SELECT id FROM medications'), ['m1']);
    });

    test('works without foreign keys enforced (no orphaned children)', () async {
      final db = await _seedProfiles(targetHasProfile: false);
      await db.customStatement('PRAGMA foreign_keys = OFF');
      await discardOwner(db, owner: 'off');
      expect(await _rows(db, 'SELECT id FROM allergy'), isEmpty);
      expect(await _rows(db, 'SELECT id FROM dose_events'), isEmpty);
    });

    test('second run is a no-op; a database with no profile table works', () async {
      final db = await _seedProfiles(targetHasProfile: true);
      await discardOwner(db, owner: 'off');
      await discardOwner(db, owner: 'off');
      expect(await _rows(db, 'SELECT id FROM health_profile'), ['p-srv']);

      final bare = _Db();
      await bare.customStatement('CREATE TABLE prescription (id TEXT, user_id TEXT)');
      await bare.customStatement("INSERT INTO prescription VALUES ('r1','off'), ('r2','srv')");
      await discardOwner(bare, owner: 'off');
      expect(await _rows(bare, 'SELECT id FROM prescription'), ['r2']);
    });
  });

  group('on the real app schema (foreign keys on)', () {
    Future<AppDatabase> seedReal() async {
      final db = AppDatabase(NativeDatabase.memory());
      for (final u in ['off', 'srv']) {
        await db.customStatement("INSERT INTO health_profile (id, user_id, updated_at) VALUES ('p-$u','$u','t')");
        await db.customStatement("INSERT INTO allergy (id, health_profile_id, name, severity, created_at) "
            "VALUES ('a-$u','p-$u','n','mild','t')");
        await db.customStatement('INSERT INTO medications (id, user_id, health_profile_id, name, schedule_type, '
            "schedule_config, start_date) VALUES ('m-$u','$u','p-$u','n','daily','{}','t')");
        await db.customStatement('INSERT INTO dose_events (id, medication_id, scheduled_at, recorded_at, outcome) '
            "VALUES ('d-$u','m-$u','t','t','taken')");
      }
      return db;
    }

    test('mergeOwner consolidates into the existing profile', () async {
      final db = await seedReal();
      addTearDown(db.close);
      await mergeOwner(db, from: 'off', to: 'srv');
      final profiles = await db.customSelect('SELECT id FROM health_profile').get();
      expect(profiles.map((r) => r.read<String>('id')), ['p-srv']);
      final allergies = await db.customSelect('SELECT DISTINCT health_profile_id AS p FROM allergy').get();
      expect(allergies.map((r) => r.read<String>('p')), ['p-srv']);
      expect((await db.customSelect('SELECT id FROM dose_events').get()).length, 2);
    });

    test('discardOwner removes only the offline owner, grandchildren included', () async {
      final db = await seedReal();
      addTearDown(db.close);
      await discardOwner(db, owner: 'off');
      final doses = await db.customSelect('SELECT id FROM dose_events').get();
      expect(doses.map((r) => r.read<String>('id')), ['d-srv']);
      final allergies = await db.customSelect('SELECT id FROM allergy').get();
      expect(allergies.map((r) => r.read<String>('id')), ['a-srv']);
      // The append-only guard is back in force afterwards.
      await expectLater(db.customStatement("DELETE FROM dose_events WHERE id = 'd-srv'"), throwsA(anything));
    });
  });
}
