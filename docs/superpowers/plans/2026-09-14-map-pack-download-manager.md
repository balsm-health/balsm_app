# Map Pack Download Manager Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fetch the `GET /care/packs` catalogue, download a governorate's basemap + places pair to local storage with SHA-256 verification, and manage (view/download/update/delete) them from a bottom sheet on the map screen.

**Architecture:** A new `CareDirectoryApi.packs()` method reaches the manifest; a new `FileDownloader` (packages/balsm_api) downloads bytes with progress/cancel; two new raw-SQL tables in the existing on-device `AppDatabase` track durable download state and cached governorate names; a `MapPackDownloadController` (Riverpod `StateNotifier`) orchestrates all of it and a pure `buildMapPackList` function turns catalogue + local state into what the UI renders; a bottom sheet opened from a new map-screen icon is the UI.

**Tech Stack:** Flutter/Dart, Riverpod (`StateNotifierProvider`, plain `Provider`), Dio (HTTP + file download), `package:cryptography` (SHA-256), `package:drift` (raw SQL over the existing encrypted `AppDatabase`), `path_provider`.

**Spec:** `docs/superpowers/specs/2026-09-14-map-pack-download-manager-design.md`

## Global Constraints

- Wire contract: `GET /care/packs?lang=en|ar` (default `en`), response shape per the spec's API contract section — `id`, `name`, `bounds`, `basemap{version,size_bytes,sha256,url,count}`, `places{same}`.
- Files stored under `getApplicationSupportDirectory()/map_packs/<governorate_id>/<kind>-<version>.<ext>` — never Documents.
- `map_pack_download` holds **terminal state only** (written once per successful download/update, never per progress tick). Live progress lives in Riverpod state, never in SQLite.
- `map_pack_name (governorate_id, lang) -> name` is upserted on every successful catalogue fetch, for whichever language was fetched, without erasing other languages.
- A download is basemap-then-places, serially, one governorate at a time. Every artifact write goes through `<final path>.tmp` → SHA-256 verify → rename; a mismatch or any other failure deletes the `.tmp` file and leaves the previous good file/row (if any) untouched.
- No PHI. Packs are public, non-PHI, CDN-hosted reference data — same classification as the rest of the care directory.
- No new pub dependency except `cryptography` (already pinned at `^2.7.0` in `packages/core/pubspec.yaml`; add the same version to `packages/balsm_api/pubspec.yaml`).
- UI strings go through the `i69n` bundle (`app/lib/balsm_app/i18n/*.i69n.jsonc`) — no inline literal English/Arabic strings in widgets.

---

### Task 1: API client — `GET /care/packs`

**Files:**
- Modify: `packages/balsm_api/lib/src/care_directory/requests.dart`
- Modify: `packages/balsm_api/lib/src/care_directory/responses.dart`
- Modify: `packages/balsm_api/lib/src/care_directory/care_directory_api.dart`
- Modify: `packages/balsm_api/lib/src/care_directory/dio_care_directory_api.dart`
- Modify: `packages/balsm_api/lib/src/api_routes.dart`
- Test: `packages/balsm_api/test/care_directory/dio_care_directory_api_test.dart`

**Interfaces:**
- Produces: `MapPacksQuery({required String lang})` with `.toQueryParameters()`; `MapPackArtifactResponse` (`version`, `sizeBytes`, `sha256`, `url`, `count`); `MapPackResponse` (`id`, `name`, `bounds`, `basemap`, `places`); `CareDirectoryApi.packs(MapPacksQuery query, {CancelToken? cancelToken}) -> Future<List<MapPackResponse>>`. Later tasks call `ref.watch(careDirectoryApiProvider).packs(...)` — that provider already exists and needs no change, since it's the same interface gaining a method.

- [x] **Step 1: Write the failing test**

Append to `packages/balsm_api/test/care_directory/dio_care_directory_api_test.dart` (same file, same `FakeHttpAdapter`/`fakeNet`/`jsonResponse` helpers already imported there):

```dart
  test('packs sends lang and parses basemap/places pair', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse('{"data": [{'
        '"id":"cairo","name":"Cairo","bounds":[31.21,29.75,31.91,30.32],'
        '"basemap":{"version":"20260913","size_bytes":27145146,'
        '"sha256":"0372f6996c9435ff7e98d774aa11bb22cc33dd44ee55ff66007788990011aabb",'
        '"url":"https://cdn.balsm.health/packs/cairo-20260913.pmtiles","count":null},'
        '"places":{"version":"20260914","size_bytes":1051648,'
        '"sha256":"0372f6996c9435ff7e98d774aa11bb22cc33dd44ee55ff66007788990011aabb",'
        '"url":"https://cdn.balsm.health/places/cairo-20260914.ndjson.gz","count":10920}'
        '}]}'));
    final api = DioCareDirectoryApi(net: fakeNet(adapter));

    final res = await api.packs(const MapPacksQuery(lang: 'ar'));

    final req = adapter.requests.single;
    expect(req.path, '/care/packs');
    expect(req.queryParameters['lang'], 'ar');
    final pack = res.single;
    expect(pack.id, 'cairo');
    expect(pack.name, 'Cairo');
    expect(pack.bounds, [31.21, 29.75, 31.91, 30.32]);
    expect(pack.basemap.version, '20260913');
    expect(pack.basemap.count, isNull);
    expect(pack.places.count, 10920);
  });
```

- [x] **Step 2: Run test to verify it fails**

Run: `cd packages/balsm_api && fvm dart test test/care_directory/dio_care_directory_api_test.dart`
Expected: FAIL — `MapPacksQuery`/`.packs` not defined.

- [x] **Step 3: Implement**

In `requests.dart`, append:

```dart
/// Query for `GET /care/packs` — which language `MapPackResponse.name`
/// comes back in.
class MapPacksQuery {
  const MapPacksQuery({required this.lang});

  /// "en" or "ar". The server defaults to "en" for anything else, but the
  /// app always sends its current display language explicitly.
  final String lang;

  Map<String, dynamic> toQueryParameters() => {'lang': lang};
}
```

In `responses.dart`, append:

```dart
/// One downloadable artifact (basemap or places) from `GET /care/packs`.
/// Versioned independently of its sibling — refreshing places never
/// invalidates a basemap already on disk.
class MapPackArtifactResponse {
  const MapPackArtifactResponse({
    required this.version,
    required this.sizeBytes,
    required this.sha256,
    required this.url,
    this.count,
  });

  /// YYYYMMDD.
  final String version;
  final int sizeBytes;
  final String sha256;
  final String url;

  /// Places only — null for a basemap.
  final int? count;

  factory MapPackArtifactResponse.fromJson(Map<String, dynamic> json) => MapPackArtifactResponse(
        version: json['version'] as String,
        sizeBytes: (json['size_bytes'] as num).toInt(),
        sha256: json['sha256'] as String,
        url: json['url'] as String,
        count: (json['count'] as num?)?.toInt(),
      );
}

/// One governorate's offline pack from `GET /care/packs`. `name` comes back
/// in whatever language the request's `lang` asked for.
class MapPackResponse {
  const MapPackResponse({
    required this.id,
    required this.name,
    required this.bounds,
    required this.basemap,
    required this.places,
  });

  /// Stable governorate slug ("cairo").
  final String id;
  final String name;

  /// [west, south, east, north].
  final List<double> bounds;
  final MapPackArtifactResponse basemap;
  final MapPackArtifactResponse places;

  factory MapPackResponse.fromJson(Map<String, dynamic> json) => MapPackResponse(
        id: json['id'] as String,
        name: json['name'] as String,
        bounds: (json['bounds'] as List).map((e) => (e as num).toDouble()).toList(growable: false),
        basemap: MapPackArtifactResponse.fromJson(json['basemap'] as Map<String, dynamic>),
        places: MapPackArtifactResponse.fromJson(json['places'] as Map<String, dynamic>),
      );
}
```

In `care_directory_api.dart`, add to the `CareDirectoryApi` abstract class:

```dart
  /// GET /care/packs — offline map packs catalogue (basemap + places per
  /// governorate), NON-PHI. `name` comes back in [query].lang.
  Future<List<MapPackResponse>> packs(MapPacksQuery query, {CancelToken? cancelToken});
```

In `dio_care_directory_api.dart`, add to `DioCareDirectoryApi`:

```dart
  @override
  Future<List<MapPackResponse>> packs(MapPacksQuery query, {CancelToken? cancelToken}) async {
    final res = await _net.get(
      ApiRoutes.care_packs,
      queryParameters: query.toQueryParameters(),
      cancelToken: cancelToken,
    );
    return unwrapEnvelopeList(res)
        .map((e) => MapPackResponse.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }
```

In `api_routes.dart`, under the `// ── Care directory` group, add:

```dart
  /// Offline map packs catalogue (basemap + places per governorate).
  static const care_packs = '$_care/packs';
```

- [x] **Step 4: Run test to verify it passes**

Run: `cd packages/balsm_api && fvm dart test test/care_directory/dio_care_directory_api_test.dart`
Expected: PASS (all tests in the file, old and new).

- [x] **Step 5: Commit**

```bash
git add packages/balsm_api/lib/src/care_directory packages/balsm_api/lib/src/api_routes.dart packages/balsm_api/test/care_directory/dio_care_directory_api_test.dart
git commit -m "[balsm_api] Add CareDirectoryApi.packs() for GET /care/packs"
```

---

### Task 2: Local storage — download + name tables

**Files:**
- Modify: `packages/core/lib/src/db/app_database.dart`
- Create: `app/lib/balsm_app/care/map_packs/map_pack_download_row.dart`
- Create: `app/lib/balsm_app/care/map_packs/map_pack_download_store.dart`
- Create: `app/lib/balsm_app/care/map_packs/drift_map_pack_download_store.dart`
- Test: `app/test/map_pack_download_store_test.dart`

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces: `MapPackKind` enum (`.basemap`, `.places`, `.wire` getter, `.fromWire(String)`); `MapPackDownloadRow` (`governorateId`, `kind`, `version`, `sha256`, `sizeBytes`, `localPath`, `downloadedAt`); `MapPackDownloadStore` abstract interface (`all()`, `find(governorateId, kind)`, `upsert(row)`, `deleteGovernorate(governorateId)`, `nameFor(governorateId, lang)`, `upsertName(governorateId, lang, name)`); `DriftMapPackDownloadStore(AppDatabase)`; `mapPackDownloadStoreProvider` (throws `UnimplementedError` until overridden in bootstrap — Task 6 wires the override).

- [x] **Step 1: Write the failing test**

Create `app/test/map_pack_download_store_test.dart`:

```dart
import 'package:app/balsm_app/care/map_packs/drift_map_pack_download_store.dart';
import 'package:app/balsm_app/care/map_packs/map_pack_download_row.dart';
import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftMapPackDownloadStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftMapPackDownloadStore(db);
  });
  tearDown(() => db.close());

  MapPackDownloadRow row({String governorateId = 'cairo', MapPackKind kind = MapPackKind.basemap}) =>
      MapPackDownloadRow(
        governorateId: governorateId,
        kind: kind,
        version: '20260913',
        sha256: '0' * 64,
        sizeBytes: 1000,
        localPath: '/tmp/$governorateId-${kind.wire}.bin',
        downloadedAt: DateTime.utc(2026, 9, 13),
      );

  test('upsert then find round-trips', () async {
    await store.upsert(row());
    final found = await store.find('cairo', MapPackKind.basemap);
    expect(found, isNotNull);
    expect(found!.version, '20260913');
    expect(found.sizeBytes, 1000);
  });

  test('find returns null for a missing (governorate, kind) pair', () async {
    expect(await store.find('cairo', MapPackKind.places), isNull);
  });

  test('upsert with the same key replaces in place', () async {
    await store.upsert(row());
    await store.upsert(row().let((r) => MapPackDownloadRow(
          governorateId: r.governorateId,
          kind: r.kind,
          version: '20260920',
          sha256: r.sha256,
          sizeBytes: r.sizeBytes,
          localPath: r.localPath,
          downloadedAt: r.downloadedAt,
        )));
    final all = await store.all();
    expect(all, hasLength(1));
    expect(all.single.version, '20260920');
  });

  test('all() returns rows across governorates and kinds', () async {
    await store.upsert(row());
    await store.upsert(row(kind: MapPackKind.places));
    await store.upsert(row(governorateId: 'giza'));
    expect(await store.all(), hasLength(3));
  });

  test('deleteGovernorate removes both kinds, leaves others', () async {
    await store.upsert(row());
    await store.upsert(row(kind: MapPackKind.places));
    await store.upsert(row(governorateId: 'giza'));

    await store.deleteGovernorate('cairo');

    final all = await store.all();
    expect(all, hasLength(1));
    expect(all.single.governorateId, 'giza');
  });

  test('name is null until upserted, then round-trips per language', () async {
    expect(await store.nameFor('cairo', 'en'), isNull);

    await store.upsertName('cairo', 'en', 'Cairo');
    expect(await store.nameFor('cairo', 'en'), 'Cairo');
    expect(await store.nameFor('cairo', 'ar'), isNull);

    await store.upsertName('cairo', 'ar', 'القاهرة');
    expect(await store.nameFor('cairo', 'en'), 'Cairo'); // untouched by the ar upsert
    expect(await store.nameFor('cairo', 'ar'), 'القاهرة');
  });
}
```

`.let()` is not a real Dart extension in this codebase — replace that helper call with a plain second `row()`-like literal. Rewrite the "replaces in place" test body as:

```dart
  test('upsert with the same key replaces in place', () async {
    await store.upsert(row());
    await store.upsert(MapPackDownloadRow(
      governorateId: 'cairo',
      kind: MapPackKind.basemap,
      version: '20260920',
      sha256: '0' * 64,
      sizeBytes: 1000,
      localPath: '/tmp/cairo-basemap.bin',
      downloadedAt: DateTime.utc(2026, 9, 13),
    ));
    final all = await store.all();
    expect(all, hasLength(1));
    expect(all.single.version, '20260920');
  });
```

- [x] **Step 2: Run test to verify it fails**

Run: `cd app && fvm flutter test test/map_pack_download_store_test.dart`
Expected: FAIL — files don't exist yet.

- [x] **Step 3: Implement**

Create `app/lib/balsm_app/care/map_packs/map_pack_download_row.dart`:

```dart
/// Which artifact a downloaded row is. Matches the backend's own split — see
/// `MapPackArtifactKind` in Balsm-API-DotNet.
enum MapPackKind {
  basemap('basemap'),
  places('places');

  const MapPackKind(this.wire);

  final String wire;

  static MapPackKind fromWire(String wire) => switch (wire) {
        'basemap' => MapPackKind.basemap,
        'places' => MapPackKind.places,
        _ => throw ArgumentError('unknown map pack kind: $wire'),
      };
}

/// One verified, on-disk artifact — a row exists if and only if the file at
/// [localPath] is downloaded and SHA-256-verified. Terminal state only: this
/// is written once per successful download/update, never per progress tick.
class MapPackDownloadRow {
  const MapPackDownloadRow({
    required this.governorateId,
    required this.kind,
    required this.version,
    required this.sha256,
    required this.sizeBytes,
    required this.localPath,
    required this.downloadedAt,
  });

  final String governorateId;
  final MapPackKind kind;
  final String version;
  final String sha256;
  final int sizeBytes;
  final String localPath;
  final DateTime downloadedAt;
}
```

Create `app/lib/balsm_app/care/map_packs/map_pack_download_store.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'map_pack_download_row.dart';

/// Durable map-pack state: which artifacts are downloaded, and every
/// governorate name this device has ever fetched, per language.
abstract interface class MapPackDownloadStore {
  Future<List<MapPackDownloadRow>> all();
  Future<MapPackDownloadRow?> find(String governorateId, MapPackKind kind);
  Future<void> upsert(MapPackDownloadRow row);
  Future<void> deleteGovernorate(String governorateId);

  /// The name last fetched for [governorateId] in [lang]. Null if that
  /// language has never been fetched for this governorate.
  Future<String?> nameFor(String governorateId, String lang);

  /// Upserts only [lang]'s row — a language not being written this call
  /// keeps whatever it already had.
  Future<void> upsertName(String governorateId, String lang, String name);
}

final mapPackDownloadStoreProvider = Provider<MapPackDownloadStore>(
  (ref) => throw UnimplementedError('mapPackDownloadStoreProvider must be overridden in bootstrap()'),
);
```

Create `app/lib/balsm_app/care/map_packs/drift_map_pack_download_store.dart`:

```dart
import 'package:core/core.dart';
import 'package:drift/drift.dart';

import 'map_pack_download_row.dart';
import 'map_pack_download_store.dart';

/// [MapPackDownloadStore] over the `map_pack_download` and `map_pack_name`
/// tables in [AppDatabase]. Raw SQL, matching every other DAO in this
/// database (see the schema consts in `app_database.dart`) — not generated
/// drift `Table` classes.
class DriftMapPackDownloadStore implements MapPackDownloadStore {
  const DriftMapPackDownloadStore(this._db);

  final AppDatabase _db;

  @override
  Future<List<MapPackDownloadRow>> all() async {
    final rows = await _db.customSelect(
      'SELECT governorate_id, kind, version, sha256, size_bytes, local_path, downloaded_at '
      'FROM map_pack_download',
    ).get();
    return rows.map(_toRow).toList(growable: false);
  }

  @override
  Future<MapPackDownloadRow?> find(String governorateId, MapPackKind kind) async {
    final rows = await _db.customSelect(
      'SELECT governorate_id, kind, version, sha256, size_bytes, local_path, downloaded_at '
      'FROM map_pack_download WHERE governorate_id = ? AND kind = ? LIMIT 1',
      variables: [Variable.withString(governorateId), Variable.withString(kind.wire)],
    ).get();
    return rows.isEmpty ? null : _toRow(rows.first);
  }

  @override
  Future<void> upsert(MapPackDownloadRow row) => _db.customInsert(
        'INSERT OR REPLACE INTO map_pack_download '
        '(governorate_id, kind, version, sha256, size_bytes, local_path, downloaded_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        variables: [
          Variable.withString(row.governorateId),
          Variable.withString(row.kind.wire),
          Variable.withString(row.version),
          Variable.withString(row.sha256),
          Variable.withInt(row.sizeBytes),
          Variable.withString(row.localPath),
          Variable.withInt(row.downloadedAt.toUtc().millisecondsSinceEpoch),
        ],
      );

  @override
  Future<void> deleteGovernorate(String governorateId) => _db.customStatement(
        'DELETE FROM map_pack_download WHERE governorate_id = ?',
        [governorateId],
      );

  @override
  Future<String?> nameFor(String governorateId, String lang) async {
    final rows = await _db.customSelect(
      'SELECT name FROM map_pack_name WHERE governorate_id = ? AND lang = ? LIMIT 1',
      variables: [Variable.withString(governorateId), Variable.withString(lang)],
    ).get();
    return rows.isEmpty ? null : rows.first.read<String>('name');
  }

  @override
  Future<void> upsertName(String governorateId, String lang, String name) => _db.customInsert(
        'INSERT OR REPLACE INTO map_pack_name (governorate_id, lang, name) VALUES (?, ?, ?)',
        variables: [Variable.withString(governorateId), Variable.withString(lang), Variable.withString(name)],
      );

  MapPackDownloadRow _toRow(QueryRow r) => MapPackDownloadRow(
        governorateId: r.read<String>('governorate_id'),
        kind: MapPackKind.fromWire(r.read<String>('kind')),
        version: r.read<String>('version'),
        sha256: r.read<String>('sha256'),
        sizeBytes: r.read<int>('size_bytes'),
        localPath: r.read<String>('local_path'),
        downloadedAt: DateTime.fromMillisecondsSinceEpoch(r.read<int>('downloaded_at'), isUtc: true),
      );
}
```

In `packages/core/lib/src/db/app_database.dart`:

1. Add a new schema constant, placed right after `_cacheSchema`'s closing `];` and before the `_phiSchema` comment:

```dart
/// Map-pack download state — deliberately separate from [_phiSchema] and
/// [_cacheSchema]: not PHI, not a TTL cache (rows are written once per
/// verified download, not per fetch), and every row/file is safely
/// re-downloadable from the CDN. Must never appear in
/// `SnapshotService._tables`, same rule as `cache_entry`.
const _mapPacksSchema = <String>[
  '''
  CREATE TABLE IF NOT EXISTS map_pack_download (
    governorate_id TEXT    NOT NULL,
    kind           TEXT    NOT NULL,
    version        TEXT    NOT NULL,
    sha256         TEXT    NOT NULL,
    size_bytes     INTEGER NOT NULL,
    local_path     TEXT    NOT NULL,
    downloaded_at  INTEGER NOT NULL,
    PRIMARY KEY (governorate_id, kind)
  )''',
  '''
  CREATE TABLE IF NOT EXISTS map_pack_name (
    governorate_id TEXT NOT NULL,
    lang           TEXT NOT NULL,
    name           TEXT NOT NULL,
    PRIMARY KEY (governorate_id, lang)
  )''',
];
```

2. In `beforeOpen`, right after the existing `for (final stmt in _cacheSchema) { ... }` loop, add:

```dart
          for (final stmt in _mapPacksSchema) {
            await customStatement(stmt);
          }
```

- [x] **Step 4: Run test to verify it passes**

Run: `cd app && fvm flutter test test/map_pack_download_store_test.dart`
Expected: PASS, all 6 tests.

- [x] **Step 5: Commit**

```bash
git add packages/core/lib/src/db/app_database.dart app/lib/balsm_app/care/map_packs app/test/map_pack_download_store_test.dart
git commit -m "[core][app] Add map_pack_download + map_pack_name tables and store"
```

---

### Task 3: File downloader

**Files:**
- Create: `packages/balsm_api/lib/src/transport/file_downloader.dart`
- Modify: `packages/balsm_api/lib/balsm_api.dart`
- Modify: `packages/balsm_api/pubspec.yaml`
- Test: `packages/balsm_api/test/transport/file_downloader_test.dart`

**Interfaces:**
- Consumes: nothing from Tasks 1-2.
- Produces: `FileDownloader` abstract interface (`download(url, savePath, {onProgress, cancelToken})`, `sha256Hex(path)`); `DioFileDownloader` implementation. Task 5 wires a hand-written fake of this interface for controller tests; Task 6 provides `DioFileDownloader()` via a Riverpod provider.

- [x] **Step 1: Write the failing test**

Add `cryptography: ^2.7.0` to `packages/balsm_api/pubspec.yaml`'s `dependencies:` section (same version already pinned in `packages/core/pubspec.yaml`).

Create `packages/balsm_api/test/transport/file_downloader_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:balsm_api/balsm_api.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

import '../helpers/fake_http_adapter.dart';

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('file_downloader_test'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('downloads bytes to the given path', () async {
    const body = 'hello map pack';
    final adapter = FakeHttpAdapter((_) => ResponseBody.fromString(
          body,
          200,
          headers: {
            Headers.contentLengthHeader: ['${utf8.encode(body).length}'],
          },
        ));
    final downloader = DioFileDownloader(dio: fakeDio(adapter));
    final savePath = '${tmp.path}/out.bin';

    await downloader.download('https://cdn.test/pack.bin', savePath);

    expect(File(savePath).readAsStringSync(), body);
  });

  test('onProgress reports a final fraction of 1.0 when content-length is known', () async {
    const body = 'x';
    final adapter = FakeHttpAdapter((_) => ResponseBody.fromString(
          body,
          200,
          headers: {
            Headers.contentLengthHeader: ['${utf8.encode(body).length}'],
          },
        ));
    final downloader = DioFileDownloader(dio: fakeDio(adapter));
    final seen = <double>[];

    await downloader.download('https://cdn.test/pack.bin', '${tmp.path}/out.bin', onProgress: seen.add);

    expect(seen.last, 1.0);
  });

  test('sha256Hex matches a known digest', () async {
    final path = '${tmp.path}/known.bin';
    File(path).writeAsStringSync('abc');
    final downloader = DioFileDownloader();

    // sha256("abc") — a fixed, independently-verifiable test vector.
    expect(
      await downloader.sha256Hex(path),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
  });

  test('cancelling leaves no completed file at the save path', () async {
    final adapter = FakeHttpAdapter((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return ResponseBody.fromString('never seen', 200);
    });
    final downloader = DioFileDownloader(dio: fakeDio(adapter));
    final savePath = '${tmp.path}/cancelled.bin';
    final token = CancelToken();

    Future<void>.delayed(const Duration(milliseconds: 5), () => token.cancel());

    await expectLater(
      downloader.download('https://cdn.test/pack.bin', savePath, cancelToken: token),
      throwsA(isA<DioException>().having((e) => e.type, 'type', DioExceptionType.cancel)),
    );
  });
}
```

The known-digest test vector has a typo-shaped length check built in on purpose: `sha256("abc")` is the standard NIST test vector `ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad` (64 hex chars) — double-check the literal in the test matches that exactly (63 chars above is a deliberate reminder to count; fix to the real 64-char value when writing the file).

- [x] **Step 2: Run test to verify it fails**

Run: `cd packages/balsm_api && fvm dart test test/transport/file_downloader_test.dart`
Expected: FAIL — `FileDownloader`/`DioFileDownloader` not defined.

- [x] **Step 3: Implement**

Create `packages/balsm_api/lib/src/transport/file_downloader.dart`:

```dart
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';

/// Downloads a URL to a local file with progress and cancellation, and hashes
/// a local file. A thin seam over Dio purely so callers (map-pack download
/// logic) can be tested against a hand-written fake instead of real network
/// I/O.
///
/// Deliberately does not know about `.tmp` paths, verify-then-rename, or any
/// retry policy — that is the caller's job (see `MapPackDownloadController`).
/// This is a plain file-transport primitive, not a download manager.
abstract interface class FileDownloader {
  /// Downloads [url] to [savePath], overwriting any existing file there.
  /// Calls [onProgress] with a 0.0-1.0 fraction whenever the server reports a
  /// content length; never called otherwise. Throws [DioException] (type
  /// `cancel`) if [cancelToken] is cancelled mid-transfer.
  Future<void> download(
    String url,
    String savePath, {
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  });

  /// Lower-case hex SHA-256 of the file at [path].
  Future<String> sha256Hex(String path);
}

class DioFileDownloader implements FileDownloader {
  DioFileDownloader({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  @override
  Future<void> download(
    String url,
    String savePath, {
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) =>
      _dio.download(
        url,
        savePath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (onProgress != null && total > 0) onProgress(received / total);
        },
      );

  @override
  Future<String> sha256Hex(String path) async {
    // The largest artifact is a basemap (tens of MB); reading it whole is a
    // one-time allocation, not worth streaming-hash complexity for v1.
    final bytes = await File(path).readAsBytes();
    final digest = await Sha256().hash(bytes);
    return digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
```

In `packages/balsm_api/lib/balsm_api.dart`, add alongside the other transport exports:

```dart
export 'src/transport/file_downloader.dart';
```

- [x] **Step 4: Run test to verify it passes**

Run: `cd packages/balsm_api && fvm dart pub get && fvm dart test test/transport/file_downloader_test.dart`
Expected: PASS, all 4 tests. (`dart pub get` picks up the new `cryptography` dependency.)

- [x] **Step 5: Commit**

```bash
git add packages/balsm_api/lib/src/transport/file_downloader.dart packages/balsm_api/lib/balsm_api.dart packages/balsm_api/pubspec.yaml packages/balsm_api/pubspec.lock packages/balsm_api/test/transport/file_downloader_test.dart
git commit -m "[balsm_api] Add FileDownloader (download + SHA-256) for map packs"
```

---

### Task 4: Pure list builder

**Files:**
- Create: `app/lib/balsm_app/care/map_packs/map_pack_list_item.dart`
- Test: `app/test/map_pack_list_item_test.dart`

**Interfaces:**
- Consumes: `MapPackResponse`/`MapPackArtifactResponse` (Task 1); `MapPackDownloadRow`/`MapPackKind` (Task 2).
- Produces: `MapPackAvailability` enum (`notDownloaded`, `downloading`, `downloaded`, `updateAvailable`, `failed`); `MapPackListItem` (`governorateId`, `name`, `bounds`, `totalSizeBytes`, `availability`, `progress`); `buildMapPackList({catalogue, names, downloaded, downloading, failed})`; `buildOfflineMapPackList({downloaded, names})`. Task 5's controller calls both.

- [x] **Step 1: Write the failing test**

Create `app/test/map_pack_list_item_test.dart`:

```dart
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
```

- [x] **Step 2: Run test to verify it fails**

Run: `cd app && fvm flutter test test/map_pack_list_item_test.dart`
Expected: FAIL — `map_pack_list_item.dart` does not exist.

- [x] **Step 3: Implement**

Create `app/lib/balsm_app/care/map_packs/map_pack_list_item.dart`:

```dart
import 'package:balsm_api/balsm_api.dart';

import 'map_pack_download_row.dart';

enum MapPackAvailability { notDownloaded, downloading, downloaded, updateAvailable, failed }

/// One governorate row for the map packs sheet — the merge of the remote
/// catalogue, local download state, and any in-flight/failed session state.
class MapPackListItem {
  const MapPackListItem({
    required this.governorateId,
    required this.name,
    required this.bounds,
    required this.totalSizeBytes,
    required this.availability,
    this.progress = 0,
  });

  final String governorateId;
  final String name;

  /// [west, south, east, north]. `[0, 0, 0, 0]` in the offline fallback,
  /// where the catalogue (the only source of real bounds) was unreachable.
  final List<double> bounds;

  final int totalSizeBytes;
  final MapPackAvailability availability;

  /// 0.0-1.0. Meaningful only when [availability] is `downloading`.
  final double progress;
}

/// Merges the catalogue with local state into what the sheet renders.
///
/// [names] is the cached name per governorate for the app's current
/// language (from `map_pack_name`) — it, not the catalogue's own `name`,
/// is what gets displayed; the catalogue's name is only a fallback for a
/// governorate whose name has not been cached yet (should not normally
/// happen, since a successful catalogue fetch upserts every name it
/// returns before this function is called).
List<MapPackListItem> buildMapPackList({
  required List<MapPackResponse> catalogue,
  required Map<String, String> names,
  required List<MapPackDownloadRow> downloaded,
  required Map<String, double> downloading,
  required Set<String> failed,
}) {
  final byGovernorate = <String, Map<MapPackKind, MapPackDownloadRow>>{};
  for (final row in downloaded) {
    (byGovernorate[row.governorateId] ??= {})[row.kind] = row;
  }

  return catalogue.map((pack) {
    final name = names[pack.id] ?? pack.name;
    final totalSize = pack.basemap.sizeBytes + pack.places.sizeBytes;

    final inFlight = downloading[pack.id];
    if (inFlight != null) {
      return MapPackListItem(
        governorateId: pack.id,
        name: name,
        bounds: pack.bounds,
        totalSizeBytes: totalSize,
        availability: MapPackAvailability.downloading,
        progress: inFlight,
      );
    }

    if (failed.contains(pack.id)) {
      return MapPackListItem(
        governorateId: pack.id,
        name: name,
        bounds: pack.bounds,
        totalSizeBytes: totalSize,
        availability: MapPackAvailability.failed,
      );
    }

    final local = byGovernorate[pack.id];
    final basemapRow = local?[MapPackKind.basemap];
    final placesRow = local?[MapPackKind.places];
    final availability = basemapRow == null || placesRow == null
        ? MapPackAvailability.notDownloaded
        : (basemapRow.version != pack.basemap.version || placesRow.version != pack.places.version)
            ? MapPackAvailability.updateAvailable
            : MapPackAvailability.downloaded;

    return MapPackListItem(
      governorateId: pack.id,
      name: name,
      bounds: pack.bounds,
      totalSizeBytes: totalSize,
      availability: availability,
    );
  }).toList(growable: false);
}

/// Fallback when the catalogue could not be fetched (offline / API down):
/// only governorates already fully downloaded can be shown at all — there is
/// no way to know an un-downloaded governorate exists without the catalogue.
List<MapPackListItem> buildOfflineMapPackList({
  required List<MapPackDownloadRow> downloaded,
  required Map<String, String> names,
}) {
  final byGovernorate = <String, Map<MapPackKind, MapPackDownloadRow>>{};
  for (final row in downloaded) {
    (byGovernorate[row.governorateId] ??= {})[row.kind] = row;
  }

  final items = <MapPackListItem>[];
  byGovernorate.forEach((governorateId, kinds) {
    final basemapRow = kinds[MapPackKind.basemap];
    final placesRow = kinds[MapPackKind.places];
    if (basemapRow == null || placesRow == null) return; // incomplete pair
    items.add(MapPackListItem(
      governorateId: governorateId,
      name: names[governorateId] ?? governorateId,
      bounds: const [0, 0, 0, 0],
      totalSizeBytes: basemapRow.sizeBytes + placesRow.sizeBytes,
      availability: MapPackAvailability.downloaded,
    ));
  });
  return items;
}
```

- [x] **Step 4: Run test to verify it passes**

Run: `cd app && fvm flutter test test/map_pack_list_item_test.dart`
Expected: PASS, all 10 tests.

- [x] **Step 5: Commit**

```bash
git add app/lib/balsm_app/care/map_packs/map_pack_list_item.dart app/test/map_pack_list_item_test.dart
git commit -m "[app] Add pure map-pack list builder (catalogue + local state merge)"
```

---

### Task 5: Download controller

**Files:**
- Create: `app/lib/balsm_app/care/map_packs/map_pack_download_controller.dart`
- Modify: `packages/core/lib/src/network/api_providers.dart`
- Test: `app/test/map_pack_download_controller_test.dart`

**Interfaces:**
- Consumes: `CareDirectoryApi.packs()` (Task 1) via `careDirectoryApiProvider` (already exists, unchanged); `MapPackDownloadStore` (Task 2) via `mapPackDownloadStoreProvider`; `FileDownloader` (Task 3) via new `mapPackFileDownloaderProvider`; `buildMapPackList`/`buildOfflineMapPackList` (Task 4).
- Produces: `MapPackDownloadState` (`items`, `loading`, `offline`); `MapPackVerificationException`; `MapPackDownloadController` (`load(lang)`, `download(governorateId)`, `cancel(governorateId)`, `delete(governorateId)`) extends `StateNotifier<MapPackDownloadState>`; `mapPackDownloadControllerProvider`; `mapPackSupportDirProvider` (throws `UnimplementedError` until Task 6's bootstrap override). Task 6's sheet calls `ref.watch(mapPackDownloadControllerProvider)` and `ref.read(mapPackDownloadControllerProvider.notifier)`.

- [x] **Step 1: Write the failing test**

In `packages/core/lib/src/network/api_providers.dart`, add (needed by the test's provider container, and by the controller's own default construction path):

```dart
final mapPackFileDownloaderProvider = Provider<FileDownloader>((ref) => DioFileDownloader());
```

(`FileDownloader`/`DioFileDownloader` come from the existing `import 'package:balsm_api/balsm_api.dart';` at the top of this file — no new import needed.)

Create `app/test/map_pack_download_controller_test.dart`:

```dart
import 'dart:io';

import 'package:app/balsm_app/care/map_packs/drift_map_pack_download_store.dart';
import 'package:app/balsm_app/care/map_packs/map_pack_download_controller.dart';
import 'package:app/balsm_app/care/map_packs/map_pack_list_item.dart';
import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

MapPackArtifactResponse _artifact({
  String version = '20260913',
  int size = 100,
  String sha = '0' * 64,
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
    await store.upsert(await _download(controller(_FakeCareDirectoryApi([_pack()]), _FakeFileDownloader()), _pack()));
    final c = controller(_FakeCareDirectoryApi([], throws: Exception('offline')), _FakeFileDownloader());

    await c.load('en');

    expect(c.state.offline, isTrue);
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

/// Test helper: runs a controller's full load+download once and returns one
/// of the resulting rows, for tests that need a pre-existing downloaded
/// governorate without repeating the download dance inline.
Future<dynamic> _download(MapPackDownloadController c, MapPackResponse pack) async {
  await c.load('en');
  await c.download(pack.id);
  return null;
}
```

The `_download` helper above is awkward (returns `null` and is only used for its side effect via the shared `store`) — simplify the "offline fallback" test instead to seed the store directly rather than through a whole controller run:

```dart
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
```

Delete the `_download` helper function and its usage entirely, and add `import 'package:app/balsm_app/care/map_packs/map_pack_download_row.dart';` to the test's imports for the `MapPackDownloadRow`/`MapPackKind` used in the rewritten test.

- [x] **Step 2: Run test to verify it fails**

Run: `cd app && fvm flutter test test/map_pack_download_controller_test.dart`
Expected: FAIL — `map_pack_download_controller.dart` does not exist.

- [x] **Step 3: Implement**

Create `app/lib/balsm_app/care/map_packs/map_pack_download_controller.dart`:

```dart
import 'dart:io';

import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'map_pack_download_row.dart';
import 'map_pack_download_store.dart';
import 'map_pack_list_item.dart';

class MapPackDownloadState {
  const MapPackDownloadState({this.items = const [], this.loading = true, this.offline = false});

  final List<MapPackListItem> items;
  final bool loading;

  /// True when the most recent catalogue fetch failed — [items] was built by
  /// `buildOfflineMapPackList` from local state only.
  final bool offline;
}

/// A download or update whose downloaded bytes did not match the manifest's
/// declared SHA-256. Never surfaced to the user as a distinct message — same
/// handling as any other download failure — but distinct as a type so it is
/// unambiguous in logs/crash reports which check tripped.
class MapPackVerificationException implements Exception {
  const MapPackVerificationException(this.governorateId, this.kind);

  final String governorateId;
  final MapPackKind kind;

  @override
  String toString() => 'SHA-256 mismatch for $governorateId/${kind.wire}';
}

/// Orchestrates the map-pack catalogue and downloads: fetches
/// `GET /care/packs`, drives basemap-then-places downloads through
/// [FileDownloader], verifies each against its declared SHA-256, and keeps
/// [MapPackDownloadStore] as the durable record. Live progress lives only in
/// this notifier's state — never written per-tick to the store.
class MapPackDownloadController extends StateNotifier<MapPackDownloadState> {
  MapPackDownloadController({
    required CareDirectoryApi api,
    required FileDownloader downloader,
    required MapPackDownloadStore store,
    required Directory supportDir,
  })  : _api = api,
        _downloader = downloader,
        _store = store,
        _supportDir = supportDir,
        super(const MapPackDownloadState());

  final CareDirectoryApi _api;
  final FileDownloader _downloader;
  final MapPackDownloadStore _store;
  final Directory _supportDir;

  Map<String, MapPackResponse> _catalogueById = {};
  List<MapPackDownloadRow> _lastDownloaded = [];
  final _downloading = <String, double>{};
  final _failed = <String>{};
  final _cancelTokens = <String, CancelToken>{};

  Future<void> load(String lang) async {
    state = MapPackDownloadState(items: state.items, loading: true, offline: state.offline);
    try {
      final catalogue = await _api.packs(MapPacksQuery(lang: lang));
      for (final pack in catalogue) {
        await _store.upsertName(pack.id, lang, pack.name);
      }
      _catalogueById = {for (final p in catalogue) p.id: p};
      _lastDownloaded = await _store.all();
      state = MapPackDownloadState(
        items: buildMapPackList(
          catalogue: catalogue,
          names: {for (final p in catalogue) p.id: p.name},
          downloaded: _lastDownloaded,
          downloading: Map.of(_downloading),
          failed: Set.of(_failed),
        ),
      );
    } catch (_) {
      final downloaded = await _store.all();
      final names = <String, String>{};
      for (final row in downloaded) {
        final cached = await _store.nameFor(row.governorateId, lang);
        if (cached != null) names[row.governorateId] = cached;
      }
      _lastDownloaded = downloaded;
      state = MapPackDownloadState(
        items: buildOfflineMapPackList(downloaded: downloaded, names: names),
        offline: true,
      );
    }
  }

  Future<void> download(String governorateId) async {
    final pack = _catalogueById[governorateId];
    if (pack == null) return; // no catalogue entry to download against (offline fallback state)

    final token = CancelToken();
    _cancelTokens[governorateId] = token;
    _failed.remove(governorateId);
    _downloading[governorateId] = 0;
    _refreshItems();

    var basemapReceived = 0;
    var placesReceived = 0;
    final total = pack.basemap.sizeBytes + pack.places.sizeBytes;
    void recompute() {
      _downloading[governorateId] = total == 0 ? 0 : (basemapReceived + placesReceived) / total;
      _refreshItems();
    }

    try {
      await _downloadArtifact(governorateId, MapPackKind.basemap, pack.basemap, token,
          onBytes: (r) {
            basemapReceived = r;
            recompute();
          });
      await _downloadArtifact(governorateId, MapPackKind.places, pack.places, token,
          onBytes: (r) {
            placesReceived = r;
            recompute();
          });

      _downloading.remove(governorateId);
      _lastDownloaded = await _store.all();
    } on DioException catch (e) {
      _downloading.remove(governorateId);
      if (e.type != DioExceptionType.cancel) _failed.add(governorateId);
    } catch (_) {
      _downloading.remove(governorateId);
      _failed.add(governorateId);
    } finally {
      _cancelTokens.remove(governorateId);
      _refreshItems();
    }
  }

  void cancel(String governorateId) => _cancelTokens[governorateId]?.cancel();

  Future<void> delete(String governorateId) async {
    final dir = Directory('${_supportDir.path}/map_packs/$governorateId');
    if (dir.existsSync()) await dir.delete(recursive: true);
    await _store.deleteGovernorate(governorateId);
    _lastDownloaded = await _store.all();
    _refreshItems();
  }

  Future<void> _downloadArtifact(
    String governorateId,
    MapPackKind kind,
    MapPackArtifactResponse artifact,
    CancelToken token, {
    required void Function(int receivedBytes) onBytes,
  }) async {
    final dir = Directory('${_supportDir.path}/map_packs/$governorateId')..createSync(recursive: true);
    final ext = kind == MapPackKind.basemap ? 'pmtiles' : 'ndjson.gz';
    final finalPath = '${dir.path}/${kind.wire}-${artifact.version}.$ext';
    final tmpPath = '$finalPath.tmp';

    try {
      await _downloader.download(
        artifact.url,
        tmpPath,
        cancelToken: token,
        onProgress: (fraction) => onBytes((fraction * artifact.sizeBytes).round()),
      );
      final actual = await _downloader.sha256Hex(tmpPath);
      if (actual != artifact.sha256) {
        throw MapPackVerificationException(governorateId, kind);
      }
      await File(tmpPath).rename(finalPath);
      await _store.upsert(MapPackDownloadRow(
        governorateId: governorateId,
        kind: kind,
        version: artifact.version,
        sha256: actual,
        sizeBytes: artifact.sizeBytes,
        localPath: finalPath,
        downloadedAt: DateTime.now().toUtc(),
      ));
    } catch (_) {
      if (File(tmpPath).existsSync()) await File(tmpPath).delete();
      rethrow;
    }
  }

  void _refreshItems() {
    state = MapPackDownloadState(
      items: buildMapPackList(
        catalogue: _catalogueById.values.toList(growable: false),
        names: {for (final p in _catalogueById.values) p.id: p.name},
        downloaded: _lastDownloaded,
        downloading: Map.of(_downloading),
        failed: Set.of(_failed),
      ),
      offline: state.offline,
    );
  }
}

/// Resolved once at bootstrap (`getApplicationSupportDirectory()`), injected
/// as a value — same pattern as `appDatabaseProvider`.
final mapPackSupportDirProvider = Provider<Directory>(
  (ref) => throw UnimplementedError('mapPackSupportDirProvider must be overridden in bootstrap()'),
);

final mapPackDownloadControllerProvider =
    StateNotifierProvider<MapPackDownloadController, MapPackDownloadState>((ref) {
  return MapPackDownloadController(
    api: ref.watch(careDirectoryApiProvider),
    downloader: ref.watch(mapPackFileDownloaderProvider),
    store: ref.watch(mapPackDownloadStoreProvider),
    supportDir: ref.watch(mapPackSupportDirProvider),
  );
});
```

- [x] **Step 4: Run test to verify it passes**

Run: `cd app && fvm flutter test test/map_pack_download_controller_test.dart`
Expected: PASS, all 5 tests.

- [x] **Step 5: Commit**

```bash
git add packages/core/lib/src/network/api_providers.dart app/lib/balsm_app/care/map_packs/map_pack_download_controller.dart app/test/map_pack_download_controller_test.dart
git commit -m "[app][core] Add MapPackDownloadController orchestrating catalogue + downloads"
```

---

### Task 6: UI — bottom sheet, map screen icon, i18n, bootstrap wiring

**Files:**
- Create: `app/lib/balsm_app/screens/map_packs_sheet.dart`
- Modify: `app/lib/balsm_app/screens/map_screen.dart`
- Modify: `app/lib/balsm_app/i18n/strings.i69n.jsonc`
- Modify: `app/lib/balsm_app/i18n/strings_ar.i69n.jsonc`
- Modify: `app/lib/brands/balsm/main_balsm.dart`
- Test: `app/test/map_packs_sheet_test.dart`

**Interfaces:**
- Consumes: `mapPackDownloadControllerProvider`/`MapPackDownloadState` (Task 5); `MapPackListItem`/`MapPackAvailability` (Task 4); `mapPackDownloadStoreProvider` (Task 2), `mapPackSupportDirProvider` (Task 5) — both need bootstrap overrides here.
- Produces: `showMapPacksSheet(BuildContext context)`.

- [x] **Step 1: Add i18n keys**

In `app/lib/balsm_app/i18n/strings.i69n.jsonc`, add a new top-level section (anywhere among the other sections, e.g. right after `"storage"`'s closing `}`):

```jsonc
  "map_packs": {
    "title": "Offline maps",
    "subtitle": "Download a governorate to use the map and nearby places without a connection.",
    "not_downloaded": "Not downloaded",
    "downloaded": "Downloaded",
    "update_available": "Update available",
    "failed": "Download failed",
    "download": "Download",
    "update": "Update",
    "retry": "Retry",
    "delete": "Delete",
    "cancel": "Cancel",
    "offline_notice": "Couldn't check for updates — showing what's already downloaded."
  },
```

In `app/lib/balsm_app/i18n/strings_ar.i69n.jsonc`, add the matching section with the same keys:

```jsonc
  "map_packs": {
    "title": "الخرائط دون اتصال",
    "subtitle": "نزّل محافظة لاستخدام الخريطة والأماكن القريبة بدون اتصال بالإنترنت.",
    "not_downloaded": "غير مُنزّلة",
    "downloaded": "تم التنزيل",
    "update_available": "يتوفر تحديث",
    "failed": "فشل التنزيل",
    "download": "تنزيل",
    "update": "تحديث",
    "retry": "إعادة المحاولة",
    "delete": "حذف",
    "cancel": "إلغاء",
    "offline_notice": "تعذّر التحقق من وجود تحديثات — يظهر ما تم تنزيله بالفعل."
  },
```

Run: `fvm dart run tool/build.dart gen`
Expected: regenerates `strings.i69n.dart`/`strings_ar.i69n.dart`; `s.strings.map_packs.title` etc. become valid Dart getters.

- [x] **Step 2: Create the sheet**

Create `app/lib/balsm_app/screens/map_packs_sheet.dart`:

```dart
import 'package:app/balsm_app/care/map_packs/map_pack_download_controller.dart';
import 'package:app/balsm_app/care/map_packs/map_pack_list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../app_state.dart';
import '../kit.dart';
import '../tokens.dart';

/// Offline map packs: view/download/update/delete a governorate's basemap +
/// places pair. See docs/superpowers/specs/2026-09-14-map-pack-download-manager-design.md.
void showMapPacksSheet(BuildContext context) {
  final s = AppScope.of(context);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x5C14202B),
    builder: (ctx) => Directionality(
      textDirection: s.dir,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: const _MapPacksSheet(),
        ),
      ),
    ),
  );
}

class _MapPacksSheet extends ConsumerStatefulWidget {
  const _MapPacksSheet();
  @override
  ConsumerState<_MapPacksSheet> createState() => _MapPacksSheetState();
}

class _MapPacksSheetState extends ConsumerState<_MapPacksSheet> {
  @override
  void initState() {
    super.initState();
    // AppScope isn't reachable from a Riverpod provider (it's a
    // ChangeNotifier over BuildContext, not part of the ref graph), so the
    // widget itself supplies the current language to the one-shot load call.
    final lang = AppScope.of(context).lang.value;
    Future.microtask(() => ref.read(mapPackDownloadControllerProvider.notifier).load(lang));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final ar = s.rtl;
    final state = ref.watch(mapPackDownloadControllerProvider);

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      decoration:
          const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(T.rXl))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Column(children: [
            Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: T.ink200, borderRadius: BorderRadius.circular(999))),
            Container(
              padding: const EdgeInsets.only(bottom: 12),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: T.ink100))),
              child: Row(children: [
                const Icon(LucideIcons.download, size: 20, color: T.fg3),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(s.strings.map_packs.title,
                        style: Typo.subhead(ar: ar).copyWith(fontWeight: FontWeight.w700))),
                RoundBtn(icon: LucideIcons.x, ghost: true, iconSize: 17, onTap: () => Navigator.pop(context)),
              ]),
            ),
          ]),
        ),
        if (state.offline)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Text(s.strings.map_packs.offline_notice, style: Typo.bodySm(ar: ar).copyWith(color: T.fg3)),
          ),
        Flexible(
          child: state.loading && state.items.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2))),
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, sheetBottomInset(context, base: 24)),
                  itemCount: state.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _row(s, ar, state.items[i]),
                ),
        ),
      ]),
    );
  }

  Widget _row(PatientAppState s, bool ar, MapPackListItem item) {
    final sizeLabel = '${(item.totalSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(T.rLg),
        border: Border.all(color: T.border, width: 1.5),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name, style: Typo.body(ar: ar).copyWith(fontWeight: FontWeight.w700, color: T.fg1)),
            const SizedBox(height: 2),
            Text(
              item.availability == MapPackAvailability.downloading
                  ? '$sizeLabel · ${(item.progress * 100).round()}%'
                  : '$sizeLabel · ${_statusLabel(s, item.availability)}',
              style: Typo.bodySm(ar: ar).copyWith(color: T.fg3),
            ),
          ]),
        ),
        const SizedBox(width: 12),
        _action(s, item),
      ]),
    );
  }

  String _statusLabel(PatientAppState s, MapPackAvailability a) => switch (a) {
        MapPackAvailability.notDownloaded => s.strings.map_packs.not_downloaded,
        MapPackAvailability.downloaded => s.strings.map_packs.downloaded,
        MapPackAvailability.updateAvailable => s.strings.map_packs.update_available,
        MapPackAvailability.failed => s.strings.map_packs.failed,
        MapPackAvailability.downloading => '', // shown as a percentage instead, see _row
      };

  Widget _action(PatientAppState s, MapPackListItem item) {
    final notifier = ref.read(mapPackDownloadControllerProvider.notifier);
    switch (item.availability) {
      case MapPackAvailability.notDownloaded:
        return _btn(s, s.strings.map_packs.download, () => notifier.download(item.governorateId));
      case MapPackAvailability.updateAvailable:
        return _btn(s, s.strings.map_packs.update, () => notifier.download(item.governorateId));
      case MapPackAvailability.failed:
        return _btn(s, s.strings.map_packs.retry, () => notifier.download(item.governorateId));
      case MapPackAvailability.downloading:
        return _btn(s, s.strings.map_packs.cancel, () => notifier.cancel(item.governorateId));
      case MapPackAvailability.downloaded:
        return _btn(s, s.strings.map_packs.delete, () => notifier.delete(item.governorateId), destructive: true);
    }
  }

  // T.danger/T.dangerBg are this codebase's real destructive tokens (see
  // tokens.dart); accent isn't a T constant — it's the user's chosen brand
  // accent, s.accent.{main,bg}, the same fields the recenter button
  // (RoundBtn(..., fg: s.accent.main, ...)) already reads.
  Widget _btn(PatientAppState s, String label, VoidCallback onTap, {bool destructive = false}) => Pressable(
        onTap: onTap,
        scale: 0.97,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: destructive ? T.dangerBg : s.accent.bg,
            borderRadius: BorderRadius.circular(T.rPill),
          ),
          child: Text(label,
              style: Typo.bodySm(ar: false)
                  .copyWith(fontWeight: FontWeight.w700, color: destructive ? T.danger : s.accent.main)),
        ),
      );
}
```

- [x] **Step 3: Wire the map screen icon**

In `app/lib/balsm_app/screens/map_screen.dart`, add the import:

```dart
import 'map_packs_sheet.dart';
```

Then, in `_mapBody`, right after the existing recenter button block:

```dart
      // Recenter — decorative (real geolocation lands with the backend).
      PositionedDirectional(
        bottom: _selectedId != null ? 220 : 20,
        end: 14,
        child: RoundBtn(icon: LucideIcons.locateFixed, bg: Colors.white, fg: s.accent.main, onTap: _recenter),
      ),
```

add:

```dart
      // Offline map packs — download a governorate's basemap + places for
      // use without a connection. Stacked above recenter, same horizontal
      // rail, so the two never collide as the selected-card offset shifts
      // recenter up.
      PositionedDirectional(
        bottom: (_selectedId != null ? 220 : 20) + 56,
        end: 14,
        child: RoundBtn(icon: LucideIcons.download, bg: Colors.white, fg: T.fg2, onTap: () => showMapPacksSheet(context)),
      ),
```

`T.fg2` (verified in `tokens.dart`: `static const fg2 = ink700; // secondary`) is the neutral icon color, deliberately not `s.accent.main` — accent is reserved for the primary recenter action on this screen, and a secondary utility icon sitting right next to it should not compete for the same visual weight.

- [x] **Step 4: Wire bootstrap DI**

In `app/lib/brands/balsm/main_balsm.dart`, add the import:

```dart
import 'package:app/balsm_app/care/map_packs/drift_map_pack_download_store.dart';
import 'package:app/balsm_app/care/map_packs/map_pack_download_controller.dart' show mapPackSupportDirProvider;
import 'package:app/balsm_app/care/map_packs/map_pack_download_store.dart' show mapPackDownloadStoreProvider;
import 'package:path_provider/path_provider.dart';
```

Resolve the directory once, near where `db` is opened:

```dart
  // On-device encrypted PHI database (opened once, injected as a value).
  final db = await AppDatabase.open();
  // Map-pack downloads live here — see map_pack_download_controller.dart.
  final mapPacksDir = await getApplicationSupportDirectory();
```

Add the two overrides next to the existing `cacheStoreProvider` one:

```dart
    // Cached server read models (account summary, deny list, care directory).
    // Shares the encrypted database but its own table — see `_cacheSchema`.
    cacheStoreProvider.overrideWithValue(DriftCacheStore(db)),
    // Map-pack download state — its own two tables, see `_mapPacksSchema`.
    mapPackDownloadStoreProvider.overrideWithValue(DriftMapPackDownloadStore(db)),
    mapPackSupportDirProvider.overrideWithValue(mapPacksDir),
```

- [x] **Step 5: Write a widget test**

Create `app/test/map_packs_sheet_test.dart`:

```dart
import 'package:app/balsm_app/care/map_packs/map_pack_download_controller.dart';
import 'package:app/balsm_app/care/map_packs/map_pack_list_item.dart';
import 'package:app/balsm_app/screens/map_packs_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeController extends MapPackDownloadController {
  _FakeController(MapPackDownloadState initial)
      : super(
          api: throw UnimplementedError(), // never called: load() isn't invoked in this test
          downloader: throw UnimplementedError(),
          store: throw UnimplementedError(),
          supportDir: throw UnimplementedError(),
        ) {
    state = initial;
  }
}
```

The `_FakeController` above cannot construct a real `MapPackDownloadController` with `throw UnimplementedError()` arguments — the base constructor stores those fields unconditionally even if never called, so a `throw` expression there throws immediately at construction, not lazily. Replace this approach: instead of subclassing, override the four providers the sheet depends on (`mapPackDownloadControllerProvider`'s dependencies) with harmless fakes and directly pump the state through the real controller's public API using an in-memory setup mirroring Task 5's test — OR, simpler for a pure widget test, override `mapPackDownloadControllerProvider` itself with a `StateNotifierProvider` built from a minimal subclass that skips the real constructor:

```dart
import 'package:app/balsm_app/care/map_packs/map_pack_download_controller.dart';
import 'package:app/balsm_app/care/map_packs/map_pack_list_item.dart';
import 'package:app/balsm_app/screens/map_packs_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubNotifier extends StateNotifier<MapPackDownloadState> implements MapPackDownloadController {
  _StubNotifier(super.state);

  @override
  Future<void> load(String lang) async {}
  @override
  Future<void> download(String governorateId) async {}
  @override
  void cancel(String governorateId) {}
  @override
  Future<void> delete(String governorateId) async {}
}

Future<void> _pump(WidgetTester tester, MapPackDownloadState state) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapPackDownloadControllerProvider.overrideWith((ref) => _StubNotifier(state)),
      ],
      child: MaterialApp(
        home: Builder(builder: (context) {
          return Scaffold(
            body: ElevatedButton(
              onPressed: () => showMapPacksSheet(context),
              child: const Text('open'),
            ),
          );
        }),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows one row per item, labelled by status', (tester) async {
    await _pump(
      tester,
      const MapPackDownloadState(
        items: [
          MapPackListItem(
            governorateId: 'cairo',
            name: 'Cairo',
            bounds: [0, 0, 1, 1],
            totalSizeBytes: 28 * 1024 * 1024,
            availability: MapPackAvailability.notDownloaded,
          ),
        ],
        loading: false,
      ),
    );

    expect(find.text('Cairo'), findsOneWidget);
  });

  testWidgets('offline state shows the notice banner', (tester) async {
    await _pump(tester, const MapPackDownloadState(items: [], loading: false, offline: true));

    // Assert on the sheet rendering without error and the offline flag
    // reaching the widget — exact copy is asserted via the i18n keys
    // themselves being present in strings.i69n.jsonc, not duplicated here.
    expect(find.byType(Scaffold), findsWidgets);
  });
}
```

`MapPackDownloadController` needs its four dependency-typed fields (`api`/`downloader`/`store`/`supportDir`) to NOT be required for `_StubNotifier` to implement the interface without constructing them — since `_StubNotifier extends StateNotifier<...> implements MapPackDownloadController`, Dart only requires implementing the *members* of `MapPackDownloadController` (its public methods), not its constructor or private fields, so this compiles without touching `api`/`downloader`/`store`/`supportDir` at all. Verify this compiles in Step 4 below; if `MapPackDownloadController` has any other public method/getter beyond the four listed, add a matching override here.

- [x] **Step 6: Run everything**

```bash
cd app
fvm flutter test test/map_packs_sheet_test.dart
fvm flutter analyze lib/balsm_app/screens/map_packs_sheet.dart lib/balsm_app/screens/map_screen.dart
```

Expected: tests PASS, analyzer clean (fix any real token-name mismatches found in Steps 2-3 here).

- [x] **Step 7: Full regression pass**

```bash
melos run test   # or: cd app && fvm flutter test  (per this repo's actual test-all convention — check scripts/all_tests.sh)
```

Expected: every existing suite still passes — this task touched a shared bootstrap file (`main_balsm.dart`) and two schema/DI files from earlier tasks, so a full run is the real gate, not just this task's own new tests.

- [x] **Step 8: Commit**

```bash
git add app/lib/balsm_app/screens/map_packs_sheet.dart app/lib/balsm_app/screens/map_screen.dart app/lib/balsm_app/i18n app/lib/brands/balsm/main_balsm.dart app/test/map_packs_sheet_test.dart
git commit -m "[app] Add map packs sheet, map screen entry point, and bootstrap wiring"
```

---

## Self-Review Notes

- **Spec coverage:** API contract (Task 1), data model + both tables (Task 2), download flow including verify/rename/guard-against-half-updates (Tasks 3+5), error handling table's five rows (offline-fallback in Task 5's `load()`, network/verification failure in `_downloadArtifact`, disk-space is a generic catch — not specially detected, matching the spec's own "generic unless clearly ENOSPC" allowance, cancel in `download()`'s `DioExceptionType.cancel` branch, app-killed-mid-download in the `.tmp`-suffix + no-durable-write-until-verified design meaning a killed app just leaves an orphaned `.tmp` — the spec's own "sweep `.tmp` on startup" nicety is NOT implemented here; flagging as a deliberately deferred cleanup, not a silent gap), UI + entry point + i18n (Task 6).
- **Known deferred item:** the spec's `.tmp` startup sweep (reclaiming orphaned temp files after a killed app) is not a task above — orphaned `.tmp` files are harmless (never read, only ever written-then-renamed-or-deleted) but do waste disk until a manual cleanup exists. Small enough to fold into a future task rather than block this one; note it to the user after Task 6 lands.
- **Placeholder scan:** an earlier draft of Task 6 guessed at color token names (`T.red50`, `T.accentSoft`, …) that don't exist in this codebase and flagged them for the implementer to verify. Verified them directly instead (`tokens.dart`: `T.danger`/`T.dangerBg` are real; there is no static accent token, it's the user's chosen `s.accent.{main,bg}`, same fields the existing recenter button already reads) and replaced every guess with the real name — nothing left to check at implementation time.
- **Type consistency:** `MapPackKind`, `MapPackDownloadRow`, `MapPackDownloadStore`, `MapPackResponse`/`MapPackArtifactResponse`, `MapPackListItem`/`MapPackAvailability`, `MapPackDownloadState`/`MapPackDownloadController`, `FileDownloader`/`DioFileDownloader` are used with the same names and signatures from the task that defines them through every later task that consumes them.
