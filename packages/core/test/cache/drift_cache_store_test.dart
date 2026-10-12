import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftCacheStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftCacheStore(db);
  });
  tearDown(() => db.close());

  test('round-trips a payload', () async {
    await store.write('account', 'u1', '{"handle":"sara"}');
    final row = await store.read('account', 'u1');
    expect(row!.payload, '{"handle":"sara"}');
    expect(row.key, 'u1');
  });

  test('namespaces are isolated', () async {
    await store.write('account', 'k', 'a');
    await store.write('care', 'k', 'b');
    expect((await store.read('account', 'k'))!.payload, 'a');
    expect((await store.read('care', 'k'))!.payload, 'b');
  });

  test('read returns null for an absent key', () async {
    expect(await store.read('account', 'nope'), isNull);
  });

  test('write overwrites in place', () async {
    await store.write('account', 'k', 'old');
    await store.write('account', 'k', 'new');
    expect((await store.read('account', 'k'))!.payload, 'new');
    expect(await store.readNamespace('account'), hasLength(1));
  });

  test('evictOldest keeps exactly the newest N of its own namespace', () async {
    for (var i = 0; i < 5; i++) {
      await store.write('care', 'q$i', 'p$i');
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    await store.write('account', 'keepme', 'x');

    await store.evictOldest('care', keep: 2);

    final care = await store.readNamespace('care');
    expect(care.map((r) => r.key).toSet(), {'q3', 'q4'});
    expect(await store.read('account', 'keepme'), isNotNull);
  });

  test('clearNamespace leaves other namespaces intact', () async {
    await store.write('care', 'a', '1');
    await store.write('account', 'b', '2');
    await store.clearNamespace('care');
    expect(await store.readNamespace('care'), isEmpty);
    expect(await store.read('account', 'b'), isNotNull);
  });

  test('clearAll empties every namespace', () async {
    await store.write('care', 'a', '1');
    await store.write('account', 'b', '2');
    await store.clearAll();
    expect(await store.readNamespace('care'), isEmpty);
    expect(await store.readNamespace('account'), isEmpty);
  });

  test('isFresh compares against fetchedAt', () {
    final fresh = CacheRow(key: 'k', payload: 'p', fetchedAt: DateTime.now().toUtc());
    final old = CacheRow(
      key: 'k',
      payload: 'p',
      fetchedAt: DateTime.now().toUtc().subtract(const Duration(hours: 2)),
    );
    expect(fresh.isFresh(const Duration(hours: 1)), isTrue);
    expect(old.isFresh(const Duration(hours: 1)), isFalse);
  });
}
