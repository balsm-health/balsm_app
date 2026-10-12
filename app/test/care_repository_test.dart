import 'package:app/balsm_app/care/care_entity.dart';
import 'package:app/balsm_app/care/infrastructure/caching_care_directory_repository.dart';
import 'package:app/balsm_app/care/infrastructure/drift_care_directory_data_source.dart';
import 'package:app/balsm_app/care/ports/care_directory_data_source.dart';
import 'package:app/balsm_app/care/ports/care_query_id.dart';
import 'package:balsm_api/balsm_api.dart' show ApiException, CancelToken;
import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

/// Synthetic. The directory is public reference data, never PHI.
CareEntity _place(String id) => CareEntity(
      id: id,
      type: CareEntityType.pharmacy,
      position: const LatLng(30.0444, 31.2357),
      name: (en: 'Fixture $id', ar: 'عينة $id'),
      addr: (en: 'Fixture Street', ar: 'شارع العينة'),
      hours: '09:00-22:00',
      distance: '0.8 km',
      rating: '4.2',
      phone: '+20000000000',
    );

/// What NetworkManager hands a caller when the request never left the device.
const _offline = ApiException(code: 'network_error', isOffline: true);

/// Counts calls so a test can prove the network was NOT hit.
class _FakeRemote implements RemoteCareDirectoryDataSource {
  _FakeRemote({this.result = const [], this.throws, this.pinResult = const [], this.detail});

  List<CareEntity> result;
  List<CarePin> pinResult;
  CareEntity? detail;
  Object? throws;
  int calls = 0;
  int pinCalls = 0;
  int detailCalls = 0;
  LatLng? lastCenter;
  CareSearch? lastSearch;
  CancelToken? lastToken;
  bool? lastNoFloor;

  @override
  Future<List<CareEntity>> nearby(LatLng center, CareSearch search, {CancelToken? cancelToken}) async {
    calls++;
    lastCenter = center;
    lastSearch = search;
    lastToken = cancelToken;
    if (throws != null) throw throws!;
    return result;
  }

  @override
  Future<List<CarePin>> pins(
    LatLng center,
    CareSearch search, {
    bool noFloor = false,
    CancelToken? cancelToken,
  }) async {
    pinCalls++;
    lastNoFloor = noFloor;
    lastToken = cancelToken;
    if (throws != null) throw throws!;
    return pinResult;
  }

  @override
  Future<CareEntity?> byId(String id, LatLng center, {CancelToken? cancelToken}) async {
    detailCalls++;
    if (throws != null) throw throws!;
    return detail;
  }
}

void main() {
  const cairo = LatLng(30.044, 31.236);

  late AppDatabase db;
  late CacheStore store;

  DriftCareDirectoryDataSource localWith({Duration ttl = const Duration(days: 7), int maxEntries = 200}) =>
      DriftCareDirectoryDataSource(store: store, ttl: ttl, maxEntries: maxEntries);

  Future<int> retainedCount() async => (await store.readNamespace('care')).length;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftCacheStore(db);
  });
  tearDown(() => db.close());

  group('DriftCareDirectoryDataSource satisfies the core DataSource contract', () {
    const a = CareQueryId.value('a');
    const b = CareQueryId.value('b');

    test('put / find / exists', () async {
      final local = localWith();

      expect(await local.find(a), isNull);
      expect(await local.exists(a), isFalse);

      await local.put(a, [_place('x')]);

      expect((await local.find(a))!.single.id, 'x');
      expect(await local.exists(a), isTrue);
    });

    test('putBulk / findMany / findAll', () async {
      final local = localWith();
      await local.putBulk({
        a: [_place('x')],
        b: [_place('y')],
      });

      expect(await local.findAll(), hasLength(2));
      expect(await local.findMany([a, b]), hasLength(2));
      // A miss is skipped, not surfaced as a null hole in the list.
      expect(await local.findMany([a, const CareQueryId.value('missing')]), hasLength(1));
    });

    test('delete / deleteMany / clear', () async {
      final local = localWith();
      await local.putBulk({
        a: [_place('x')],
        b: [_place('y')],
      });

      await local.delete(a);
      expect(await local.exists(a), isFalse);
      expect(await local.exists(b), isTrue);

      await local.putBulk({
        a: [_place('x')],
      });
      await local.deleteMany([a, b]);
      expect(await retainedCount(), 0);

      await local.put(a, [_place('x')]);
      await local.clear();
      expect(await retainedCount(), 0);
    });

    test('every field survives the round-trip', () async {
      final local = localWith();
      final original = _place('full');
      await local.put(a, [original]);

      // A second source over the same database, so the in-memory tier cannot
      // answer and the row genuinely comes back off disk.
      final restored = (await localWith().find(a))!.single;

      expect(restored.id, original.id);
      expect(restored.type, original.type);
      expect(restored.position.latitude, original.position.latitude);
      expect(restored.position.longitude, original.position.longitude);
      expect(restored.name, original.name);
      expect(restored.addr, original.addr);
      expect(restored.hours, original.hours);
      expect(restored.distance, original.distance);
      expect(restored.rating, original.rating);
      expect(restored.phone, original.phone);
    });

    test('a result survives a relaunch', () async {
      await localWith().put(a, [_place('x')]);
      // A fresh source over the same database is what a relaunch looks like.
      expect((await localWith().find(a))!.single.id, 'x',
          reason: 'surviving the process is the whole reason this replaced the memory-only source');
    });

    test('an undecodable payload reads as a miss, not an error', () async {
      await store.write('care', 'a', 'not json at all');
      expect(await localWith().find(a), isNull);
    });
  });

  group('CachingCareDirectoryRepository', () {
    test('a miss fetches and retains', () async {
      final remote = _FakeRemote(result: [_place('a')]);
      final repo = CachingCareDirectoryRepository(remote: remote, local: localWith());

      final first = await repo.nearby(cairo, const CareSearch());

      expect(first.entities.single.id, 'a');
      expect(first.stale, isFalse);
      expect(remote.calls, 1);
      expect(await retainedCount(), 1);
    });

    test('a hit never touches the network', () async {
      final remote = _FakeRemote(result: [_place('a')]);
      final repo = CachingCareDirectoryRepository(remote: remote, local: localWith());

      await repo.nearby(cairo, const CareSearch());
      final second = await repo.nearby(cairo, const CareSearch());

      expect(remote.calls, 1, reason: 'the second query is answered from retention');
      expect(second.entities.single.id, 'a');
    });

    test('a different search is a different question', () async {
      final remote = _FakeRemote(result: [_place('a')]);
      final repo = CachingCareDirectoryRepository(remote: remote, local: localWith());

      await repo.nearby(cairo, const CareSearch());
      await repo.nearby(cairo, const CareSearch(text: 'lab'));
      await repo.nearby(cairo, const CareSearch(types: {CareEntityType.dentist}));

      expect(remote.calls, 3);
    });

    test('a failure is not retained as if it were an answer', () async {
      // A transient blip must not look like an empty area for the whole TTL.
      final remote = _FakeRemote(throws: StateError('network down'));
      final repo = CachingCareDirectoryRepository(remote: remote, local: localWith());

      await expectLater(repo.nearby(cairo, const CareSearch()), throwsStateError);

      expect(await retainedCount(), 0, reason: 'nothing retained');

      remote.throws = null;
      remote.result = [_place('recovered')];
      final retry = await repo.nearby(cairo, const CareSearch());

      expect(retry.entities.single.id, 'recovered', reason: 'a retry must reach the network again');
      expect(remote.calls, 2);
    });

    test('an empty result IS retained — "nothing here" is a real answer', () async {
      final remote = _FakeRemote(result: const []);
      final repo = CachingCareDirectoryRepository(remote: remote, local: localWith());

      expect((await repo.nearby(cairo, const CareSearch())).entities, isEmpty);
      expect((await repo.nearby(cairo, const CareSearch())).entities, isEmpty);

      expect(remote.calls, 1, reason: 'an empty area should not be re-asked on every pan back');
    });

    test('passes the cancel token through to the remote source', () async {
      final remote = _FakeRemote();
      final repo = CachingCareDirectoryRepository(remote: remote, local: localWith());
      final token = CancelToken();

      await repo.nearby(cairo, const CareSearch(), cancelToken: token);

      expect(remote.lastToken, same(token));
    });

    test('forwards the centre and search unchanged', () async {
      final remote = _FakeRemote();
      final repo = CachingCareDirectoryRepository(remote: remote, local: localWith());
      const search = CareSearch(text: 'scan', radiusKm: 25);

      await repo.nearby(cairo, search);

      expect(remote.lastCenter, cairo);
      expect(remote.lastSearch!.text, 'scan');
      expect(remote.lastSearch!.radiusKm, 25);
    });

    test('an expired row is refetched and comes back fresh', () async {
      final remote = _FakeRemote(result: [_place('old')]);
      final repo = CachingCareDirectoryRepository(remote: remote, local: localWith(ttl: Duration.zero));
      await repo.nearby(cairo, const CareSearch());

      remote.result = [_place('new')];
      final got = await repo.nearby(cairo, const CareSearch());

      expect(got.entities.single.id, 'new');
      expect(got.stale, isFalse);
    });

    test('an offline refetch returns the expired row marked stale', () async {
      final remote = _FakeRemote(result: [_place('old')]);
      final repo = CachingCareDirectoryRepository(remote: remote, local: localWith(ttl: Duration.zero));
      await repo.nearby(cairo, const CareSearch());

      remote.throws = _offline;
      final got = await repo.nearby(cairo, const CareSearch());

      expect(got.entities.single.id, 'old');
      expect(got.stale, isTrue, reason: 'the map notice reads this, not the connectivity stream');
    });

    test('a server error is never answered from an expired row', () async {
      final remote = _FakeRemote(result: [_place('old')]);
      final repo = CachingCareDirectoryRepository(remote: remote, local: localWith(ttl: Duration.zero));
      await repo.nearby(cairo, const CareSearch());

      remote.throws = const ApiException(code: 'server_error', statusCode: 500);

      await expectLater(repo.nearby(cairo, const CareSearch()), throwsA(isA<ApiException>()));
    });

    test('an offline failure with nothing retained still throws', () async {
      final remote = _FakeRemote(throws: _offline);
      final repo = CachingCareDirectoryRepository(remote: remote, local: localWith());

      await expectLater(repo.nearby(cairo, const CareSearch()), throwsA(isA<ApiException>()));
    });

    test('the retained set is bounded', () async {
      final remote = _FakeRemote(result: [_place('x')]);
      final repo = CachingCareDirectoryRepository(remote: remote, local: localWith(maxEntries: 3));

      for (var i = 0; i < 6; i++) {
        await repo.nearby(LatLng(30.0 + i, 31.0), const CareSearch());
      }

      expect(await retainedCount(), 3);
    });
  });

  group('pins', () {
    final pin = CarePin.of(_place('p1'));

    test('a pin query is retained and then answered without the network', () async {
      final remote = _FakeRemote(pinResult: [pin]);
      final repo = CachingCareDirectoryRepository(remote: remote, local: localWith());

      final first = await repo.pins(cairo, const CareSearch());
      final second = await repo.pins(cairo, const CareSearch());

      expect(first.pins.single.id, 'p1');
      expect(second.pins.single.id, 'p1');
      expect(remote.pinCalls, 1, reason: 'pins were the one thing on the map that was never cached');
    });

    test('a pin query and a list query do not share a key', () async {
      final remote = _FakeRemote(result: [_place('a')], pinResult: [pin]);
      final repo = CachingCareDirectoryRepository(remote: remote, local: localWith());

      await repo.nearby(cairo, const CareSearch());
      await repo.pins(cairo, const CareSearch());

      expect(remote.calls, 1);
      expect(remote.pinCalls, 1, reason: 'one key for both would serve each in answer to the other');
    });

    test('the no-floor flag changes the key and is forwarded', () async {
      final remote = _FakeRemote(pinResult: [pin]);
      final repo = CachingCareDirectoryRepository(remote: remote, local: localWith());

      await repo.pins(cairo, const CareSearch());
      await repo.pins(cairo, const CareSearch(), noFloor: true);

      expect(remote.pinCalls, 2, reason: 'noFloor swaps both the radius and the limit actually sent');
      expect(remote.lastNoFloor, isTrue);
    });

    test('an offline refetch returns expired pins marked stale', () async {
      final remote = _FakeRemote(pinResult: [pin]);
      final repo = CachingCareDirectoryRepository(remote: remote, local: localWith(ttl: Duration.zero));
      await repo.pins(cairo, const CareSearch());

      remote.throws = _offline;
      final got = await repo.pins(cairo, const CareSearch());

      expect(got.pins.single.id, 'p1');
      expect(got.stale, isTrue);
    });
  });

  group('byId', () {
    test('a retained place is returned without the network', () async {
      final remote = _FakeRemote(detail: _place('d1'));
      final repo = CachingCareDirectoryRepository(remote: remote, local: localWith());

      await repo.byId('d1', cairo);
      final second = await repo.byId('d1', cairo);

      expect(second!.id, 'd1');
      expect(remote.detailCalls, 1);
    });

    test('a missing place is not retained as an answer', () async {
      final remote = _FakeRemote(detail: null);
      final repo = CachingCareDirectoryRepository(remote: remote, local: localWith());

      expect(await repo.byId('gone', cairo), isNull);
      expect(await retainedCount(), 0);
    });

    test('offline with nothing retained reads as a missing place', () async {
      final remote = _FakeRemote(throws: _offline);
      final repo = CachingCareDirectoryRepository(remote: remote, local: localWith());

      expect(await repo.byId('d1', cairo), isNull,
          reason: 'the sheet has an empty state; an error dialog would be no more informative');
    });

    test('a server error still surfaces', () async {
      final remote = _FakeRemote(throws: const ApiException(code: 'server_error', statusCode: 500));
      final repo = CachingCareDirectoryRepository(remote: remote, local: localWith());

      await expectLater(repo.byId('d1', cairo), throwsA(isA<ApiException>()));
    });
  });
}
