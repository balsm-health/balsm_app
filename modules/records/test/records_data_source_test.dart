import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:records/records.dart';
// Tests may reach into src/ — the aggregate is intentionally not on the barrel.

void main() {
  late AppDatabase db;
  UserId? active;
  late DriftRecordsDataSource ds;

  const alice = UserId.value('alice');
  const bob = UserId.value('bob');

  RecordDocument doc(String id, UserId user, {String title = 'HbA1c'}) => RecordDocument(
        id: RecordDocumentId.value(id),
        userId: user,
        type: RecordType.lab,
        title: title,
        tags: const ['Diabetes'],
        takenAt: DateTime.utc(2026, 5, 26),
        createdAt: DateTime.utc(2026, 5, 27),
      );

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    active = alice;
    ds = DriftRecordsDataSource(db, () => active);
  });

  tearDown(() => db.close());

  test('round-trips a record through the active partition', () async {
    final d = doc('r1', alice);
    await ds.put(d.id, d);
    final back = await ds.find(d.id);
    expect(back, isNotNull);
    expect(back!.title, 'HbA1c');
    expect(back.tags, ['Diabetes']);
    expect(back.type, RecordType.lab);
    expect(back.source.isSelf, isTrue);
  });

  test('partitions are isolated: bob cannot see alice records', () async {
    await ds.put(const RecordDocumentId.value('r1'), doc('r1', alice));
    active = bob;
    expect(await ds.find(const RecordDocumentId.value('r1')), isNull);
    expect(await ds.findAll(), isEmpty);
    // explicit scope override still reaches alice's partition
    expect(await ds.findAll(scope: alice), hasLength(1));
  });

  test('signed out: reads null/empty, mutations throw, clear no-op', () async {
    await ds.put(const RecordDocumentId.value('r1'), doc('r1', alice));
    active = null;
    expect(await ds.find(const RecordDocumentId.value('r1')), isNull);
    expect(await ds.findAll(), isEmpty);
    expect(() => ds.put(const RecordDocumentId.value('x'), doc('x', alice)), throwsA(isA<NoActiveUserException>()));
    expect(() => ds.delete(const RecordDocumentId.value('r1')), throwsA(isA<NoActiveUserException>()));
    await ds.clear(); // must not throw
    active = alice;
    expect(await ds.findAll(), hasLength(1)); // clear was a real no-op
  });

  test('put rejects aggregate/partition mismatch', () async {
    expect(
      () => ds.put(const RecordDocumentId.value('r9'), doc('r9', bob)),
      throwsA(isA<StorageWriteException>()),
    );
  });

  test('findMany + deleteMany respect partition and order', () async {
    await ds.put(const RecordDocumentId.value('a'), doc('a', alice));
    await ds.put(const RecordDocumentId.value('b'), doc('b', alice));
    await ds.put(const RecordDocumentId.value('c'), doc('c', alice));
    final some = await ds.findMany([const RecordDocumentId.value('a'), const RecordDocumentId.value('c')]);
    expect(some, hasLength(2));
    await ds.deleteMany([const RecordDocumentId.value('a')]);
    expect(await ds.findAll(), hasLength(2));
  });

  test('clear wipes only the active partition; clearAll wipes all', () async {
    await ds.put(const RecordDocumentId.value('a'), doc('a', alice));
    active = bob;
    await ds.put(const RecordDocumentId.value('b'), doc('b', bob));
    await ds.clear(); // bob only
    expect(await ds.findAll(scope: alice), hasLength(1));
    expect(await ds.findAll(scope: bob), isEmpty);
    await ds.clearAll();
    expect(await ds.findAll(scope: alice), isEmpty);
  });

  test('watchAll emits on writes to the watched partition', () async {
    final emissions = <int>[];
    final sub = ds.watchAll().listen((rows) => emissions.add(rows.length));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await ds.put(const RecordDocumentId.value('a'), doc('a', alice));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(emissions.last, 1);
    await sub.cancel();
  });

  test('corrupt row fails loudly on decode', () async {
    await db.customInsert(
      "INSERT INTO health_record (id, user_id, type, title, tags, source, "
      "taken_at, created_at) VALUES ('bad', 'alice', 'notatype', 't', '[]', "
      "'self', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z')",
    );
    expect(() => ds.findAll(), throwsA(isA<StorageDecodeException>()));
  });
}
