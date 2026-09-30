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
