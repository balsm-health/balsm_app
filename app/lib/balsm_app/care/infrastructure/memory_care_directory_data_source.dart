import '../care_cache.dart';
import '../care_entity.dart';
import '../ports/care_directory_data_source.dart';

/// [LocalCareDirectoryDataSource] backed by an in-memory bounded LRU.
///
/// In memory rather than on disk deliberately: the directory is refreshed
/// server-side by re-import, and a result kept across launches could outlive a
/// facility that has closed. Bandwidth is worth saving within a session; a
/// stale phone number is not worth saving between them.
class MemoryCareDirectoryDataSource implements LocalCareDirectoryDataSource {
  MemoryCareDirectoryDataSource({CareDirectoryCache? cache}) : _cache = cache ?? CareDirectoryCache();

  final CareDirectoryCache _cache;

  @override
  List<CareEntity>? read(String key) => _cache.get(key);

  @override
  void write(String key, List<CareEntity> entities) => _cache.put(key, entities);

  @override
  void clear() => _cache.clear();

  /// Retained result count — for tests and diagnostics.
  int get length => _cache.length;
}
