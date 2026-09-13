import 'dart:io';

import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'map_pack_download_row.dart';
import 'map_pack_download_store.dart';
import 'map_pack_list_item.dart';

class MapPackDownloadState {
  /// [loading] defaults true: the only initial state is "created, and the
  /// sheet is about to call load()". Defaulting false renders one frame of an
  /// empty list before the spinner — reading as "no packs exist" rather than
  /// "not fetched yet". Every other construction sets it explicitly.
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
  var _cachedNames = <String, String>{};

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
        loading: false,
      );
    } catch (_) {
      final downloaded = await _store.all();
      final names = <String, String>{};
      for (final row in downloaded) {
        final cached = await _store.nameFor(row.governorateId, lang);
        if (cached != null) names[row.governorateId] = cached;
      }
      _lastDownloaded = downloaded;
      _cachedNames = names;
      state = MapPackDownloadState(
        items: buildOfflineMapPackList(downloaded: downloaded, names: names),
        loading: false,
        offline: true,
      );
    }
  }

  Future<void> download(String governorateId) async {
    if (_downloading.isNotEmpty) return; // One download at a time app-wide.
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
      await _downloadArtifact(governorateId, MapPackKind.basemap, pack.basemap, token, onBytes: (r) {
        basemapReceived = r;
        recompute();
      });
      await _downloadArtifact(governorateId, MapPackKind.places, pack.places, token, onBytes: (r) {
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
      if (actual.toLowerCase() != artifact.sha256.toLowerCase()) {
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
    if (state.offline) {
      state = MapPackDownloadState(
        items: buildOfflineMapPackList(downloaded: _lastDownloaded, names: _cachedNames),
        loading: false,
        offline: true,
      );
      return;
    }
    state = MapPackDownloadState(
      items: buildMapPackList(
        catalogue: _catalogueById.values.toList(growable: false),
        names: {for (final p in _catalogueById.values) p.id: p.name},
        downloaded: _lastDownloaded,
        downloading: Map.of(_downloading),
        failed: Set.of(_failed),
      ),
      loading: false,
      offline: false,
    );
  }
}

/// Resolved once at bootstrap (`getApplicationSupportDirectory()`), injected
/// as a value — same pattern as `appDatabaseProvider`.
final mapPackSupportDirProvider = Provider<Directory>(
  (ref) => throw UnimplementedError('mapPackSupportDirProvider must be overridden in bootstrap()'),
);

final mapPackDownloadControllerProvider = StateNotifierProvider<MapPackDownloadController, MapPackDownloadState>((ref) {
  return MapPackDownloadController(
    api: ref.watch(careDirectoryApiProvider),
    downloader: ref.watch(mapPackFileDownloaderProvider),
    store: ref.watch(mapPackDownloadStoreProvider),
    supportDir: ref.watch(mapPackSupportDirProvider),
  );
});
