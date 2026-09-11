import '../care_cache.dart';
import '../care_entity.dart';
import '../ports/care_directory_data_source.dart';
import '../ports/care_query_id.dart';

/// [LocalCareDirectoryDataSource] backed by a bounded, TTL'd in-memory LRU.
///
/// In memory rather than on disk deliberately: the directory is refreshed
/// server-side by re-import, and a result surviving a launch could outlive a
/// facility that has closed. Bandwidth is worth saving within a session; a
/// stale phone number is not worth saving between them.
///
/// The async signatures come from the core [DataSource] contract, which is
/// written for storage that genuinely awaits. Nothing here does — every method
/// returns an already-completed future — but honouring the shared shape is what
/// lets this be swapped for a drift- or disk-backed tier later without touching
/// a caller.
class MemoryCareDirectoryDataSource extends LocalCareDirectoryDataSource {
  MemoryCareDirectoryDataSource({CareDirectoryCache? cache}) : _cache = cache ?? CareDirectoryCache();

  final CareDirectoryCache _cache;

  @override
  Future<List<CareEntity>?> find(CareQueryId key) async => _cache.get(key.value);

  @override
  Future<List<List<CareEntity>>> findAll() async => _cache.values;

  @override
  Future<List<List<CareEntity>>> findMany(Iterable<CareQueryId> keys) async =>
      keys.map((k) => _cache.get(k.value)).nonNulls.toList(growable: false);

  @override
  Future<bool> exists(CareQueryId key) async => _cache.get(key.value) != null;

  @override
  Future<void> put(CareQueryId key, List<CareEntity> value) async => _cache.put(key.value, value);

  @override
  Future<void> putBulk(Map<CareQueryId, List<CareEntity>> values) async {
    values.forEach((key, value) => _cache.put(key.value, value));
  }

  @override
  Future<void> delete(CareQueryId key) async => _cache.remove(key.value);

  @override
  Future<void> deleteMany(Iterable<CareQueryId> keys) async {
    for (final key in keys) {
      _cache.remove(key.value);
    }
  }

  @override
  Future<void> clear() async => _cache.clear();

  /// Retained result count — for tests and diagnostics.
  int get length => _cache.length;
}
