import 'package:app/balsm_app/care/map_packs/map_pack_download_row.dart';
import 'package:app/balsm_app/care/map_packs/map_pack_list_item.dart';
import 'package:balsm_api/balsm_api.dart';
import 'package:flutter_test/flutter_test.dart';

MapPackArtifactResponse _artifact({String version = '20260913', int size = 1000, String sha = 'x'}) =>
    MapPackArtifactResponse(version: version, sizeBytes: size, sha256: sha, url: 'https://cdn.test/$version');

MapPackResponse _pack(String id, {String basemapVersion = '20260913', String placesVersion = '20260914'}) =>
    MapPackResponse(
      id: id,
      name: id[0].toUpperCase() + id.substring(1),
      bounds: const [0, 0, 1, 1],
      basemap: _artifact(version: basemapVersion, size: 27000000),
      places: _artifact(version: placesVersion, size: 1000000),
    );

MapPackDownloadRow _row(String governorateId, MapPackKind kind, String version) => MapPackDownloadRow(
      governorateId: governorateId,
      kind: kind,
      version: version,
      sha256: '0' * 64,
      sizeBytes: 1000,
      localPath: '/tmp/$governorateId-${kind.wire}',
      downloadedAt: DateTime.utc(2026, 9, 13),
    );

void main() {
  group('buildMapPackList', () {
    test('not downloaded when no local rows exist', () {
      final items = buildMapPackList(
        catalogue: [_pack('cairo')],
        names: const {},
        downloaded: const [],
        downloading: const {},
        failed: const {},
      );
      expect(items.single.availability, MapPackAvailability.notDownloaded);
      expect(items.single.name, 'Cairo'); // falls back to the catalogue's own name
    });

    test('downloaded when both kinds match the catalogue version', () {
      final items = buildMapPackList(
        catalogue: [_pack('cairo')],
        names: const {'cairo': 'Cairo'},
        downloaded: [
          _row('cairo', MapPackKind.basemap, '20260913'),
          _row('cairo', MapPackKind.places, '20260914'),
        ],
        downloading: const {},
        failed: const {},
      );
      expect(items.single.availability, MapPackAvailability.downloaded);
    });

    test('update available when either kind is a stale version', () {
      final items = buildMapPackList(
        catalogue: [_pack('cairo', placesVersion: '20260915')],
        names: const {},
        downloaded: [
          _row('cairo', MapPackKind.basemap, '20260913'),
          _row('cairo', MapPackKind.places, '20260914'), // stale vs the catalogue's 20260915
        ],
        downloading: const {},
        failed: const {},
      );
      expect(items.single.availability, MapPackAvailability.updateAvailable);
    });

    test('missing one kind locally is not downloaded, not partially anything', () {
      final items = buildMapPackList(
        catalogue: [_pack('cairo')],
        names: const {},
        downloaded: [_row('cairo', MapPackKind.basemap, '20260913')], // places never downloaded
        downloading: const {},
        failed: const {},
      );
      expect(items.single.availability, MapPackAvailability.notDownloaded);
    });

    test('an in-flight download reports its fraction, overriding local state', () {
      final items = buildMapPackList(
        catalogue: [_pack('cairo')],
        names: const {},
        downloaded: const [],
        downloading: const {'cairo': 0.42},
        failed: const {},
      );
      expect(items.single.availability, MapPackAvailability.downloading);
      expect(items.single.progress, 0.42);
    });

    test('a failed governorate reports failed, not its stale local state', () {
      final items = buildMapPackList(
        catalogue: [_pack('cairo')],
        names: const {},
        downloaded: [
          _row('cairo', MapPackKind.basemap, '20260913'),
          _row('cairo', MapPackKind.places, '20260914'),
        ],
        downloading: const {},
        failed: const {'cairo'},
      );
      expect(items.single.availability, MapPackAvailability.failed);
    });

    test('the cached name wins over the catalogue name when both exist', () {
      final items = buildMapPackList(
        catalogue: [_pack('cairo')], // catalogue name is "Cairo" (English, from _pack helper)
        names: const {'cairo': 'القاهرة'}, // cached Arabic — what the app is actually displaying
        downloaded: const [],
        downloading: const {},
        failed: const {},
      );
      expect(items.single.name, 'القاهرة');
    });

    test('totalSizeBytes sums basemap and places', () {
      final items = buildMapPackList(
        catalogue: [_pack('cairo')],
        names: const {},
        downloaded: const [],
        downloading: const {},
        failed: const {},
      );
      expect(items.single.totalSizeBytes, 27000000 + 1000000);
    });
  });

  group('buildOfflineMapPackList', () {
    test('shows a governorate only when both kinds are downloaded', () {
      final items = buildOfflineMapPackList(
        downloaded: [_row('cairo', MapPackKind.basemap, '20260913')], // places missing
        names: const {},
      );
      expect(items, isEmpty);
    });

    test('shows a fully-downloaded governorate as downloaded', () {
      final items = buildOfflineMapPackList(
        downloaded: [
          _row('cairo', MapPackKind.basemap, '20260913'),
          _row('cairo', MapPackKind.places, '20260914'),
        ],
        names: const {'cairo': 'Cairo'},
      );
      expect(items.single.governorateId, 'cairo');
      expect(items.single.name, 'Cairo');
      expect(items.single.availability, MapPackAvailability.downloaded);
    });

    test('falls back to the governorate id when no name was ever cached', () {
      final items = buildOfflineMapPackList(
        downloaded: [
          _row('cairo', MapPackKind.basemap, '20260913'),
          _row('cairo', MapPackKind.places, '20260914'),
        ],
        names: const {},
      );
      expect(items.single.name, 'cairo');
    });
  });
}
