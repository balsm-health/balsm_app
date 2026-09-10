import 'package:app/balsm_app/care/care_entity.dart';
import 'package:app/balsm_app/care/infrastructure/caching_care_directory_repository.dart';
import 'package:app/balsm_app/care/infrastructure/memory_care_directory_data_source.dart';
import 'package:app/balsm_app/care/ports/care_directory_data_source.dart';
import 'package:balsm_api/balsm_api.dart' show CancelToken;
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

CareEntity _place(String id) => CareEntity(
      id: id,
      type: CareEntityType.pharmacy,
      position: const LatLng(30.0444, 31.2357),
      name: (en: 'Fixture $id', ar: ''),
      addr: (en: 'Fixture Street', ar: ''),
      hours: '',
      distance: '',
      rating: '',
      phone: '',
    );

/// Counts calls so a test can prove the network was NOT hit.
class _FakeRemote implements RemoteCareDirectoryDataSource {
  _FakeRemote({this.result = const [], this.throws});

  List<CareEntity> result;
  Object? throws;
  int calls = 0;
  LatLng? lastCenter;
  CareSearch? lastSearch;
  CancelToken? lastToken;

  @override
  Future<List<CareEntity>> nearby(LatLng center, CareSearch search, {CancelToken? cancelToken}) async {
    calls++;
    lastCenter = center;
    lastSearch = search;
    lastToken = cancelToken;
    if (throws != null) throw throws!;
    return result;
  }
}

void main() {
  const cairo = LatLng(30.044, 31.236);

  group('CachingCareDirectoryRepository', () {
    test('a miss fetches and retains', () async {
      final remote = _FakeRemote(result: [_place('a')]);
      final local = MemoryCareDirectoryDataSource();
      final repo = CachingCareDirectoryRepository(remote: remote, local: local);

      final first = await repo.nearby(cairo, const CareSearch());

      expect(first.single.id, 'a');
      expect(remote.calls, 1);
      expect(local.length, 1);
    });

    test('a hit never touches the network', () async {
      final remote = _FakeRemote(result: [_place('a')]);
      final repo = CachingCareDirectoryRepository(remote: remote, local: MemoryCareDirectoryDataSource());

      await repo.nearby(cairo, const CareSearch());
      final second = await repo.nearby(cairo, const CareSearch());

      expect(remote.calls, 1, reason: 'the second query is answered from retention');
      expect(second.single.id, 'a');
    });

    test('a different search is a different question', () async {
      final remote = _FakeRemote(result: [_place('a')]);
      final repo = CachingCareDirectoryRepository(remote: remote, local: MemoryCareDirectoryDataSource());

      await repo.nearby(cairo, const CareSearch());
      await repo.nearby(cairo, const CareSearch(text: 'lab'));
      await repo.nearby(cairo, const CareSearch(types: {CareEntityType.dentist}));

      expect(remote.calls, 3);
    });

    test('a failure is not retained as if it were an answer', () async {
      // A transient blip must not look like an empty area for the whole TTL.
      final remote = _FakeRemote(throws: StateError('network down'));
      final local = MemoryCareDirectoryDataSource();
      final repo = CachingCareDirectoryRepository(remote: remote, local: local);

      await expectLater(repo.nearby(cairo, const CareSearch()), throwsStateError);

      expect(local.length, 0, reason: 'nothing retained');

      remote.throws = null;
      remote.result = [_place('recovered')];
      final retry = await repo.nearby(cairo, const CareSearch());

      expect(retry.single.id, 'recovered', reason: 'a retry must reach the network again');
      expect(remote.calls, 2);
    });

    test('an empty result IS retained — "nothing here" is a real answer', () async {
      final remote = _FakeRemote(result: const []);
      final repo = CachingCareDirectoryRepository(remote: remote, local: MemoryCareDirectoryDataSource());

      expect(await repo.nearby(cairo, const CareSearch()), isEmpty);
      expect(await repo.nearby(cairo, const CareSearch()), isEmpty);

      expect(remote.calls, 1, reason: 'an empty area should not be re-asked on every pan back');
    });

    test('passes the cancel token through to the remote source', () async {
      final remote = _FakeRemote();
      final repo = CachingCareDirectoryRepository(remote: remote, local: MemoryCareDirectoryDataSource());
      final token = CancelToken();

      await repo.nearby(cairo, const CareSearch(), cancelToken: token);

      expect(remote.lastToken, same(token));
    });

    test('forwards the centre and search unchanged', () async {
      final remote = _FakeRemote();
      final repo = CachingCareDirectoryRepository(remote: remote, local: MemoryCareDirectoryDataSource());
      const search = CareSearch(text: 'scan', radiusKm: 25);

      await repo.nearby(cairo, search);

      expect(remote.lastCenter, cairo);
      expect(remote.lastSearch!.text, 'scan');
      expect(remote.lastSearch!.radiusKm, 25);
    });
  });
}
