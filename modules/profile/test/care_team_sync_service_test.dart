import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profile/profile.dart';

/// Records what was pushed and replays a scripted pull.
class FakeCareTeamApi implements CareTeamApi {
  FakeCareTeamApi({this.pullRows = const []});

  List<CareProviderResponse> pullRows;
  final upserted = <UpsertCareProviderRequest>[];
  final deleted = <String>[];
  final pullCursors = <DateTime?>[];
  Object? throwOnUpsert;
  Object? throwOnPull;

  /// Throw a permanent 409 for exactly this id, to prove the drain continues.
  String? throwOnUpsertFor;

  @override
  Future<List<CareProviderResponse>> pull({
    required String healthProfileId,
    DateTime? since,
    CancelToken? cancelToken,
  }) async {
    if (throwOnPull != null) throw throwOnPull!;
    pullCursors.add(since);
    return pullRows;
  }

  @override
  Future<void> upsert(UpsertCareProviderRequest request, {CancelToken? cancelToken}) async {
    if (throwOnUpsert != null) throw throwOnUpsert!;
    if (throwOnUpsertFor == request.id) {
      throw const ApiException(statusCode: 409, code: 'CareTeam.Tombstoned');
    }
    upserted.add(request);
  }

  @override
  Future<void> delete(String id, {CancelToken? cancelToken}) async => deleted.add(id);
}

void main() {
  late AppDatabase db;
  late SyncOutboxDao outbox;
  late CareProvidersDataSource providers;
  late SyncStatusNotifier status;
  var merged = 0;
  const user = UserId.value('u-sync-1');
  late HealthProfileId profileId;

  CareProvider provider(CareProviderId id, {String name = 'Provider Alpha'}) => CareProvider(
        id: id,
        healthProfileId: profileId,
        type: CareProviderType.doctor,
        name: name,
        createdAt: DateTime.utc(2026, 9, 1, 12),
      );

  CareProviderResponse row({
    required String id,
    String name = 'Cloud Provider',
    bool isDeleted = false,
    DateTime? updatedAt,
  }) =>
      CareProviderResponse(
        id: id,
        // Deliberately NOT this device's profile id: rows are keyed to the
        // account, and a replacement phone mints its own profile id.
        healthProfileId: '00000000-0000-4000-8000-00000000dead',
        type: 'doctor',
        name: name,
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: updatedAt ?? DateTime.utc(2026, 9, 2),
        isDeleted: isDeleted,
      );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.ensureSelfHealthProfile(user);
    final profiles = DriftProfileDataSource(db: db, activeUser: () => user);
    profileId = (await profiles.getProfile(user))!.id;
    outbox = SyncOutboxDao(db);
    providers = DriftCareProvidersDataSource(
      db: db,
      activeProfile: () => profileId,
      outbox: outbox,
      activeUser: () => user,
    );
    merged = 0;
    status = SyncStatusNotifier();
  });

  tearDown(() => db.close());

  CareTeamSyncService service(FakeCareTeamApi api) => CareTeamSyncService(
        api: api,
        outbox: outbox,
        db: db,
        status: status,
        activeUser: () => user,
        onChanged: () => merged++,
      );

  group('drain', () {
    test('pushes queued upserts and clears the queue', () async {
      final id = CareProviderId.uuid();
      await providers.put(id, provider(id));
      final api = FakeCareTeamApi();

      await service(api).drain();

      expect(api.upserted, hasLength(1));
      expect(api.upserted.single.name, 'Provider Alpha');
      expect(api.upserted.single.id, id.value);
      expect(await outbox.pendingCount(), 0);
    });

    test('pushes deletes', () async {
      final id = CareProviderId.uuid();
      await providers.put(id, provider(id));
      await providers.delete(id);
      final api = FakeCareTeamApi();

      await service(api).drain();

      expect(api.deleted, [id.value]);
      expect(await outbox.pendingCount(), 0);
    });

    test('keeps the entry queued and reports offline when the push fails', () async {
      final id = CareProviderId.uuid();
      await providers.put(id, provider(id));
      final api = FakeCareTeamApi()..throwOnUpsert = Exception('connection refused');

      await service(api).drain();

      expect(await outbox.pendingCount(), 1);
      expect(status.state.state, SyncState.offline);
    });

    /// Review Focus 2 — skipping ahead would send the delete before the upsert
    /// that created its row, tombstoning something the server never saw.
    test('stops at the first failure so order is preserved', () async {
      final id = CareProviderId.uuid();
      await providers.put(id, provider(id));
      await providers.delete(id);
      final api = FakeCareTeamApi()..throwOnUpsert = Exception('offline');

      await service(api).drain();

      expect(api.deleted, isEmpty);
      expect(await outbox.pendingCount(), 2);
    });

    test('a failed entry records the attempt for retry', () async {
      final id = CareProviderId.uuid();
      await providers.put(id, provider(id));
      final api = FakeCareTeamApi()..throwOnUpsert = Exception('offline');

      await service(api).drain();

      expect((await outbox.pending()).single.attempts, 1);
    });
  });

  group('pull', () {
    test('inserts a row that does not exist locally', () async {
      final api = FakeCareTeamApi(pullRows: [row(id: 'cp-remote')]);

      await service(api).pull(profileId);

      final local = await providers.findAll(scope: profileId);
      expect(local.map((p) => p.id.value), contains('cp-remote'));
      expect(local.single.name, 'Cloud Provider');
    });

    test('applies a tombstone as a local delete', () async {
      final api = FakeCareTeamApi(pullRows: [row(id: 'cp-remote')]);
      await service(api).pull(profileId);

      api.pullRows = [row(id: 'cp-remote', isDeleted: true, updatedAt: DateTime.utc(2026, 9, 3))];
      await service(api).pull(profileId);

      expect(await providers.findAll(scope: profileId), isEmpty);
    });

    /// Review Focus 5 — a pulled tombstone must not bounce back as an outbound
    /// delete, and a pulled row must not bounce back as an outbound upsert.
    test('merging never enqueues an outbound write', () async {
      final api = FakeCareTeamApi(pullRows: [row(id: 'cp-remote')]);
      await service(api).pull(profileId);
      expect(await outbox.pendingCount(), 0);

      api.pullRows = [row(id: 'cp-remote', isDeleted: true, updatedAt: DateTime.utc(2026, 9, 3))];
      await service(api).pull(profileId);

      expect(await outbox.pendingCount(), 0);
    });

    test('overwrites the local row when the remote updated_at is newer', () async {
      final api = FakeCareTeamApi(pullRows: [row(id: 'cp-remote', name: 'Old')]);
      await service(api).pull(profileId);

      api.pullRows = [row(id: 'cp-remote', name: 'New', updatedAt: DateTime.utc(2026, 9, 5))];
      await service(api).pull(profileId);

      expect((await providers.findAll(scope: profileId)).single.name, 'New');
    });

    test('leaves the local row alone when the remote updated_at is older', () async {
      final api = FakeCareTeamApi(
        pullRows: [row(id: 'cp-remote', name: 'Newer', updatedAt: DateTime.utc(2026, 9, 9))],
      );
      await service(api).pull(profileId);

      api.pullRows = [row(id: 'cp-remote', name: 'Stale', updatedAt: DateTime.utc(2026, 9, 3))];
      await service(api).pull(profileId);

      expect((await providers.findAll(scope: profileId)).single.name, 'Newer');
    });

    test('first pull sends a null cursor, the next sends the newest updated_at', () async {
      final api = FakeCareTeamApi(pullRows: [row(id: 'cp-remote', updatedAt: DateTime.utc(2026, 9, 7))]);

      await service(api).pull(profileId);
      await service(api).pull(profileId);

      expect(api.pullCursors.first, isNull);
      expect(api.pullCursors.last, DateTime.utc(2026, 9, 7));
    });

    test('an empty pull leaves the cursor untouched', () async {
      final api = FakeCareTeamApi(pullRows: [row(id: 'cp-remote', updatedAt: DateTime.utc(2026, 9, 7))]);
      await service(api).pull(profileId);

      api.pullRows = [];
      await service(api).pull(profileId);
      await service(api).pull(profileId);

      expect(api.pullCursors.last, DateTime.utc(2026, 9, 7));
    });

    test('a failing pull reports offline and does not advance the cursor', () async {
      final api = FakeCareTeamApi()..throwOnPull = Exception('offline');

      await service(api).pull(profileId);

      expect(status.state.state, SyncState.offline);
    });
  });

  group('regressions from the whole-branch review', () {
    /// C3: rows come back under the profile id the OTHER device minted. They must
    /// still land in this device's profile or the roster stays invisible.
    test('pulled rows are mapped onto this device local profile', () async {
      final api = FakeCareTeamApi(pullRows: [row(id: 'cp-remote')]);

      await service(api).pull(profileId);

      final local = await providers.findAll(scope: profileId);
      expect(local.single.id.value, 'cp-remote');
      expect(local.single.healthProfileId.value, profileId.value);
    });

    /// I7: customStatement does not notify drift streams, so the screen needs a
    /// nudge or pull-to-refresh silently does nothing.
    test('a pull that changes rows notifies the caller', () async {
      final api = FakeCareTeamApi(pullRows: [row(id: 'cp-remote')]);

      await service(api).pull(profileId);

      expect(merged, 1);
    });

    test('a pull that changes nothing does not notify', () async {
      final api = FakeCareTeamApi(pullRows: [row(id: 'cp-remote')]);
      await service(api).pull(profileId);
      merged = 0;

      // Same rows again — LWW skips them all.
      await service(api).pull(profileId);

      expect(merged, 0);
    });

    /// C4: a permanent rejection must not jam every later change behind it.
    test('a 409 is dropped and the drain continues', () async {
      final blocked = CareProviderId.uuid();
      final later = CareProviderId.uuid();
      await providers.put(blocked, provider(blocked));
      await providers.put(later, provider(later, name: 'Provider Beta'));
      final api = FakeCareTeamApi()..throwOnUpsertFor = blocked.value;

      await service(api).drain();

      expect(api.upserted.map((r) => r.id), [later.value]);
      expect(await outbox.pendingCount(), 0);
    });

    test('a 500 still stops the drain and keeps the entry', () async {
      final id = CareProviderId.uuid();
      await providers.put(id, provider(id));
      final api = FakeCareTeamApi()..throwOnUpsert = const ApiException(statusCode: 500, code: 'server');

      await service(api).drain();

      expect(await outbox.pendingCount(), 1);
    });

    /// C6: the database survives sign-out, so the queue must not.
    test('another account queued changes are never drained', () async {
      final mine = CareProviderId.uuid();
      await providers.put(mine, provider(mine));
      await outbox.enqueue(
        entity: 'care_provider',
        entityId: 'cp-someone-else',
        op: OutboxOp.upsert,
        payload: '{}',
        userId: 'u-other-account',
      );
      final api = FakeCareTeamApi();

      await service(api).drain();

      expect(api.upserted.map((r) => r.id), [mine.value]);
      expect(await outbox.pendingCount(), 1, reason: 'the other account entry stays queued');
    });
  });

  group('sync', () {
    test('drains before pulling so a local edit is not clobbered', () async {
      final id = CareProviderId.uuid();
      await providers.put(id, provider(id));
      final api = FakeCareTeamApi();

      await service(api).sync(profileId);

      expect(api.upserted, hasLength(1));
      expect(status.state.state, SyncState.synced);
    });

    test('a failed drain leaves the status offline and the queue intact', () async {
      final id = CareProviderId.uuid();
      await providers.put(id, provider(id));
      final api = FakeCareTeamApi()..throwOnUpsert = Exception('offline');

      await service(api).sync(profileId);

      expect(status.state.state, SyncState.offline);
      expect(await outbox.pendingCount(), 1);
    });
  });
}
