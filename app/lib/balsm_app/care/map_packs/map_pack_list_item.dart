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
