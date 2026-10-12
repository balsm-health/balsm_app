import 'dart:io';

import 'package:app/balsm_app/care/map_packs/drift_map_pack_download_store.dart';
import 'package:app/balsm_app/care/map_packs/map_pack_download_controller.dart';
import 'package:app/balsm_app/care/map_packs/map_pack_download_row.dart';
import 'package:app/balsm_app/care/map_packs/map_pack_list_item.dart';
import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const _shaZero = '0000000000000000000000000000000000000000000000000000000000000000';

MapPackArtifactResponse _artifact({
  String version = '20260913',
  int size = 100,
  String sha = _shaZero,
  String url = 'https://cdn.test/x',
}) =>
    MapPackArtifactResponse(version: version, sizeBytes: size, sha256: sha, url: url);

MapPackResponse _pack({
  String id = 'cairo',
  String name = 'Cairo',
  MapPackArtifactResponse? basemap,
  MapPackArtifactResponse? places,
}) =>
    MapPackResponse(
      id: id,
      name: name,
      bounds: const [0, 0, 1, 1],
      basemap: basemap ?? _artifact(url: 'https://cdn.test/$id-basemap'),
      places: places ?? _artifact(url: 'https://cdn.test/$id-places'),
    );

class _FakeCareDirectoryApi implements CareDirectoryApi {
  _FakeCareDirectoryApi(this.packsResult, {this.throws});
  List<MapPackResponse> packsResult;
  Object? throws;

  @override
  Future<List<MapPackResponse>> packs(MapPacksQuery query, {CancelToken? cancelToken}) async {
    if (throws != null) throw throws!;
    return packsResult;
  }

  @override
  Future<CareEntityResponse?> byId(String id, {double? lat, double? lng, CancelToken? cancelToken}) =>
      throw UnimplementedError();
  @override
  Future<List<CareEntityResponse>> nearby(NearbyCareQuery query, {CancelToken? cancelToken}) =>
      throw UnimplementedError();
  @override
  Future<List<CarePinResponse>> pins(CarePinsQuery query, {CancelToken? cancelToken}) => throw UnimplementedError();
}

/// Writes deterministic bytes so a caller-supplied `wantSha256` can be
/// matched or deliberately mismatched.
class _FakeFileDownloader implements FileDownloader {
  final downloadedUrls = <String>[];

  @override
  Future<void> download(String url, String savePath,
      {void Function(double progress)? onProgress, CancelToken? cancelToken}) async {
    downloadedUrls.add(url);
    onProgress?.call(0.5);
    File(savePath).writeAsStringSync(url); // content is just the url — irrelevant, only its hash matters
    onProgress?.call(1.0);
  }

  @override
  Future<String> sha256Hex(String path) async => File(path).readAsStringSync(); // fake "hash" == file content
}

void main() {
  late AppDatabase db;
  late DriftMapPackDownloadStore store;
  late Directory tmp;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftMapPackDownloadStore(db);
    tmp = Directory.systemTemp.createTempSync('map_pack_controller_test');
  });
  tearDown(() {
    db.close();
    tmp.deleteSync(recursive: true);
  });

  MapPackDownloadController controller(CareDirectoryApi api, FileDownloader downloader) => MapPackDownloadController(
        api: api,
        downloader: downloader,
        store: store,
        supportDir: tmp,
      );

  test('load() populates items from the catalogue and upserts names', () async {
    final c = controller(_FakeCareDirectoryApi([_pack()]), _FakeFileDownloader());

    await c.load('en');

    expect(c.state.items.single.governorateId, 'cairo');
    expect(c.state.items.single.availability, MapPackAvailability.notDownloaded);
    expect(c.state.offline, isFalse);
    expect(await store.nameFor('cairo', 'en'), 'Cairo');
  });

  test('load() falls back to offline mode when the catalogue fetch fails', () async {
    await store.upsert(MapPackDownloadRow(
      governorateId: 'cairo',
      kind: MapPackKind.basemap,
      version: '20260913',
      sha256: '0' * 64,
      sizeBytes: 100,
      localPath: '${tmp.path}/cairo-basemap',
      downloadedAt: DateTime.utc(2026, 9, 13),
    ));
    await store.upsert(MapPackDownloadRow(
      governorateId: 'cairo',
      kind: MapPackKind.places,
      version: '20260914',
      sha256: '0' * 64,
      sizeBytes: 100,
      localPath: '${tmp.path}/cairo-places',
      downloadedAt: DateTime.utc(2026, 9, 13),
    ));
    final c = controller(_FakeCareDirectoryApi([], throws: Exception('offline')), _FakeFileDownloader());

    await c.load('en');

    expect(c.state.offline, isTrue);
    expect(c.state.items.single.governorateId, 'cairo');
  });

  test('a successful download verifies both artifacts and upserts both rows', () async {
    // The fake downloader's "hash" is just the file content, which is the
    // url it downloaded — so wiring sha256 == url makes verification pass.
    final pack = _pack(
      basemap: _artifact(url: 'https://cdn.test/cairo-basemap', sha: 'https://cdn.test/cairo-basemap'),
      places: _artifact(url: 'https://cdn.test/cairo-places', sha: 'https://cdn.test/cairo-places'),
    );
    final c = controller(_FakeCareDirectoryApi([pack]), _FakeFileDownloader());
    await c.load('en');

    await c.download('cairo');

    final rows = await store.all();
    expect(rows, hasLength(2));
    expect(c.state.items.single.availability, MapPackAvailability.downloaded);
  });

  test('a SHA-256 mismatch fails the download and leaves no row', () async {
    final pack = _pack(basemap: _artifact(url: 'https://cdn.test/x', sha: 'does-not-match'));
    final c = controller(_FakeCareDirectoryApi([pack]), _FakeFileDownloader());
    await c.load('en');

    await c.download('cairo');

    expect(await store.all(), isEmpty);
    expect(c.state.items.single.availability, MapPackAvailability.failed);
  });

  test('delete removes both rows and the governorate directory', () async {
    final pack = _pack(
      basemap: _artifact(url: 'https://cdn.test/cairo-basemap', sha: 'https://cdn.test/cairo-basemap'),
      places: _artifact(url: 'https://cdn.test/cairo-places', sha: 'https://cdn.test/cairo-places'),
    );
    final c = controller(_FakeCareDirectoryApi([pack]), _FakeFileDownloader());
    await c.load('en');
    await c.download('cairo');
    expect(await store.all(), hasLength(2));

    await c.delete('cairo');

    expect(await store.all(), isEmpty);
    expect(Directory('${tmp.path}/map_packs/cairo').existsSync(), isFalse);
  });
}
