import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late SyncOutboxDao dao;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dao = SyncOutboxDao(db);
    // Force beforeOpen to run so the raw-SQL PHI schema is applied.
    await db.customSelect('SELECT 1').get();
  });

  tearDown(() => db.close());

  test('enqueue then pending returns the entry', () async {
    await dao.enqueue(entity: 'care_provider', entityId: 'cp-1', op: OutboxOp.upsert, payload: '{"a":1}');

    final pending = await dao.pending();
    expect(pending, hasLength(1));
    expect(pending.single.entityId, 'cp-1');
    expect(pending.single.entity, 'care_provider');
    expect(pending.single.op, OutboxOp.upsert);
    expect(pending.single.payload, '{"a":1}');
    expect(pending.single.attempts, 0);
  });

  test('pending returns entries in insertion order (FIFO)', () async {
    await dao.enqueue(entity: 'care_provider', entityId: 'cp-1', op: OutboxOp.upsert, payload: '{}');
    await dao.enqueue(entity: 'care_provider', entityId: 'cp-1', op: OutboxOp.delete, payload: '{}');

    final pending = await dao.pending();
    expect(pending.map((e) => e.op).toList(), [OutboxOp.upsert, OutboxOp.delete]);
  });

  test('complete removes the entry', () async {
    await dao.enqueue(entity: 'care_provider', entityId: 'cp-1', op: OutboxOp.upsert, payload: '{}');
    final entry = (await dao.pending()).single;

    await dao.complete(entry.id);

    expect(await dao.pending(), isEmpty);
  });

  test('fail keeps the entry and increments attempts', () async {
    await dao.enqueue(entity: 'care_provider', entityId: 'cp-1', op: OutboxOp.upsert, payload: '{}');
    final entry = (await dao.pending()).single;

    await dao.fail(entry.id, 'connection refused');

    final again = (await dao.pending()).single;
    expect(again.attempts, 1);
    expect(again.id, entry.id);
  });

  test('fail twice increments to two', () async {
    await dao.enqueue(entity: 'care_provider', entityId: 'cp-1', op: OutboxOp.upsert, payload: '{}');
    final entry = (await dao.pending()).single;

    await dao.fail(entry.id, 'boom');
    await dao.fail(entry.id, 'boom again');

    expect((await dao.pending()).single.attempts, 2);
  });

  test('pending respects the limit but keeps the oldest first', () async {
    for (var i = 0; i < 5; i++) {
      await dao.enqueue(entity: 'care_provider', entityId: 'cp-$i', op: OutboxOp.upsert, payload: '{}');
    }

    final page = await dao.pending(limit: 2);
    expect(page.map((e) => e.entityId).toList(), ['cp-0', 'cp-1']);
  });

  test('pendingCount counts every queued entry', () async {
    await dao.enqueue(entity: 'care_provider', entityId: 'cp-1', op: OutboxOp.upsert, payload: '{}');
    await dao.enqueue(entity: 'care_provider', entityId: 'cp-2', op: OutboxOp.delete, payload: '{}');

    expect(await dao.pendingCount(), 2);
  });

  test('care_provider gained updated_at and deleted_at', () async {
    final columns = await db.customSelect('PRAGMA table_info(care_provider)').get();
    final names = columns.map((r) => r.read<String>('name')).toSet();
    expect(names, containsAll(['updated_at', 'deleted_at']));
  });
}
