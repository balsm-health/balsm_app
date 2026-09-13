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
