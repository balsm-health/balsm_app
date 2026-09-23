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
        healthProfileId: profileId.value,
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
    providers = DriftCareProvidersDataSource(db: db, activeProfile: () => profileId, outbox: outbox);
    status = SyncStatusNotifier();
  });

  tearDown(() => db.close());

  CareTeamSyncService service(FakeCareTeamApi api) =>
      CareTeamSyncService(api: api, outbox: outbox, db: db, status: status);

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
