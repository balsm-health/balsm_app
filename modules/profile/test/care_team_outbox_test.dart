import 'dart:convert';

import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profile/profile.dart';

/// Every local care-team write must also queue a push (FR-506).
///
/// The outbox is optional: without one the data source behaves exactly as it
/// did before cloud sync existed, which is what keeps every other test and any
/// build without sync working unchanged.
void main() {
  late AppDatabase db;
  late SyncOutboxDao outbox;
  late HealthProfilesDataSource profiles;
  late CareProvidersDataSource providers;
  const user = UserId.value('u-outbox-1');
  late HealthProfileId profileId;

  CareProvider provider(CareProviderId id, {String name = 'Provider Alpha'}) => CareProvider(
        id: id,
        healthProfileId: profileId,
        type: CareProviderType.doctor,
        name: name,
        createdAt: DateTime.utc(2026, 9, 1, 12),
      );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.ensureSelfHealthProfile(user);
    outbox = SyncOutboxDao(db);
    profiles = DriftProfileDataSource(db: db, activeUser: () => user);
    profileId = (await profiles.getProfile(user))!.id;
    providers = DriftCareProvidersDataSource(
      db: db,
      activeProfile: () => profileId,
      outbox: outbox,
    );
  });

  tearDown(() => db.close());

  test('put enqueues an upsert carrying the row', () async {
    final id = CareProviderId.uuid();

    await providers.put(id, provider(id));

    final pending = await outbox.pending();
    expect(pending, hasLength(1));
    expect(pending.single.entity, 'care_provider');
    expect(pending.single.entityId, id.value);
    expect(pending.single.op, OutboxOp.upsert);

    final payload = jsonDecode(pending.single.payload) as Map<String, dynamic>;
    expect(payload['id'], id.value);
    expect(payload['health_profile_id'], profileId.value);
    expect(payload['type'], 'doctor');
    expect(payload['name'], 'Provider Alpha');
    expect(payload['created_at'], '2026-09-01T12:00:00.000Z');
  });

  test('re-putting the same id enqueues a second upsert with the new values', () async {
    final id = CareProviderId.uuid();
    await providers.put(id, provider(id));
    await providers.put(id, provider(id, name: 'Provider Beta'));

    final pending = await outbox.pending();
    expect(pending, hasLength(2));
    expect(jsonDecode(pending.last.payload)['name'], 'Provider Beta');
  });

  test('delete enqueues a delete', () async {
    final id = CareProviderId.uuid();
    await providers.put(id, provider(id));

    await providers.delete(id);

    final pending = await outbox.pending();
    expect(pending.last.op, OutboxOp.delete);
    expect(pending.last.entityId, id.value);
  });

  /// Review Focus 2 — draining out of order would tombstone then re-create.
  test('put then delete of one id stay in that order', () async {
    final id = CareProviderId.uuid();
    await providers.put(id, provider(id));
    await providers.delete(id);

    expect((await outbox.pending()).map((e) => e.op).toList(), [OutboxOp.upsert, OutboxOp.delete]);
  });

  test('putBulk enqueues one entry per row', () async {
    final a = CareProviderId.uuid();
    final b = CareProviderId.uuid();

    await providers.putBulk({a: provider(a), b: provider(b, name: 'Provider Beta')});

    expect(await outbox.pendingCount(), 2);
  });

  test('deleteMany enqueues one delete per id', () async {
    final a = CareProviderId.uuid();
    final b = CareProviderId.uuid();
    await providers.putBulk({a: provider(a), b: provider(b)});

    await providers.deleteMany([a, b]);

    final deletes = (await outbox.pending()).where((e) => e.op == OutboxOp.delete);
    expect(deletes.map((e) => e.entityId).toSet(), {a.value, b.value});
  });

  test('without an outbox the data source still writes locally and queues nothing', () async {
    final plain = DriftCareProvidersDataSource(db: db, activeProfile: () => profileId);
    final id = CareProviderId.uuid();

    await plain.put(id, provider(id));

    expect((await plain.findAll(scope: profileId)).map((p) => p.id.value), contains(id.value));
    expect(await outbox.pendingCount(), 0);
  });

  test('the local row is written even though a push is queued', () async {
    final id = CareProviderId.uuid();

    await providers.put(id, provider(id));

    // ADR-11: local is the write path, the queue is a mirror — never a gate.
    expect((await providers.findAll(scope: profileId)).single.name, 'Provider Alpha');
  });
}
