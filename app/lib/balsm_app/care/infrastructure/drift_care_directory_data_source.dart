import 'dart:convert';

import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../care_cache.dart';
import '../care_entity.dart';
import '../ports/care_directory_data_source.dart';
import '../ports/care_query_id.dart';

/// How long a retained directory result is used before a refetch is attempted.
///
/// The directory is refreshed server-side by re-import, so a result can outlive
/// a facility that has closed. Seven days bounds that; the map's stale notice
/// discloses it. The governorate-pack project replaces this with versioned data
/// carrying a real "as of" date, at which point revisit the number.
const _careTtl = Duration(days: 7);

/// Retained query results, evicting least-recently-fetched beyond this.
const _careMaxEntries = 200;

const _careNamespace = 'care';

/// [LocalCareDirectoryDataSource] over the shared `cache_entry` table, with an
/// in-memory tier in front.
///
/// Two tiers, because they answer different questions. The memory tier (LRU by
/// access) makes a repeated pan within one session cost no I/O. The database
/// tier — evicting by fetch time, the only timestamp a row carries — is what
/// survives a relaunch, which is the whole reason this replaced the
/// memory-only source.
class DriftCareDirectoryDataSource extends LocalCareDirectoryDataSource {
  DriftCareDirectoryDataSource({
    required CacheStore store,
    Duration ttl = _careTtl,
    int maxEntries = _careMaxEntries,
    CareDirectoryCache? memory,
  })  : _store = store,
        _ttl = ttl,
        _maxEntries = maxEntries,
        _memory = memory ?? CareDirectoryCache();

  final CacheStore _store;
  final Duration _ttl;
  final int _maxEntries;
  final CareDirectoryCache _memory;

  /// Fetch times for the in-memory tier.
  ///
  /// [CareDirectoryCache] stores values only, so without this the hot tier
  /// would answer every hit as fresh and the TTL would apply to the database
  /// tier alone — a long session would then never refetch, whatever the TTL
  /// said. Kept beside the cache rather than inside it because eviction is the
  /// cache's business and expiry is this source's.
  final _memoryFetchedAt = <String, DateTime>{};

  @override
  Future<({List<CareEntity> value, bool expired})?> findRow(CareQueryId key) async {
    final hot = _memory.get(key.value);
    if (hot != null && _memoryIsFresh(key.value)) return (value: hot, expired: false);

    final row = await _store.read(_careNamespace, key.value);
    if (row == null) return null;
    final decoded = _decodeList(row.payload, CareEntity.fromJson);
    if (decoded == null) return null;
    if (!row.isFresh(_ttl)) return (value: decoded, expired: true);

    _remember(key.value, decoded, row.fetchedAt);
    return (value: decoded, expired: false);
  }

  @override
  Future<List<CareEntity>?> find(CareQueryId key) async => (await findRow(key))?.value;

  @override
  Future<void> put(CareQueryId key, List<CareEntity> value) async {
    _remember(key.value, value, DateTime.now().toUtc());
    await _write(key.value, value.map((e) => e.toJson()).toList(growable: false));
  }

  @override
  Future<({List<CarePin> value, bool expired})?> findPins(CarePinQueryId key) async {
    final row = await _store.read(_careNamespace, key.value);
    if (row == null) return null;
    final decoded = _decodeList(row.payload, CarePin.fromJson);
    if (decoded == null) return null;
    return (value: decoded, expired: !row.isFresh(_ttl));
  }

  @override
  Future<void> putPins(CarePinQueryId key, List<CarePin> value) =>
      _write(key.value, value.map((e) => e.toJson()).toList(growable: false));

  @override
  Future<CareEntity?> findEntity(CareEntityId key) async {
    final row = await _store.read(_careNamespace, key.value);
    if (row == null || !row.isFresh(_ttl)) return null;
    try {
      return CareEntity.fromJson(jsonDecode(row.payload) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> putEntity(CareEntityId key, CareEntity value) async {
    await _store.write(_careNamespace, key.value, jsonEncode(value.toJson()));
    await _store.evictOldest(_careNamespace, keep: _maxEntries);
  }

  Future<void> _write(String key, List<Map<String, dynamic>> rows) async {
    await _store.write(_careNamespace, key, jsonEncode(rows));
    await _store.evictOldest(_careNamespace, keep: _maxEntries);
  }

  /// A payload this build can no longer read is a miss, not an error — a shape
  /// change across an app upgrade must not brick the map until reinstall.
  List<T>? _decodeList<T>(String payload, T Function(Map<String, dynamic>) fromJson) {
    try {
      return (jsonDecode(payload) as List).map((e) => fromJson(e as Map<String, dynamic>)).toList(growable: false);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<List<CareEntity>>> findAll() async => _memory.values;

  @override
  Future<List<List<CareEntity>>> findMany(Iterable<CareQueryId> keys) async {
    final out = <List<CareEntity>>[];
    for (final k in keys) {
      final hit = await find(k);
      if (hit != null) out.add(hit);
    }
    return out;
  }

  @override
  Future<bool> exists(CareQueryId key) async => await find(key) != null;

  @override
  Future<void> putBulk(Map<CareQueryId, List<CareEntity>> values) async {
    for (final e in values.entries) {
      await put(e.key, e.value);
    }
  }

  @override
  Future<void> delete(CareQueryId key) async {
    _memory.remove(key.value);
    _memoryFetchedAt.remove(key.value);
    await _store.delete(_careNamespace, key.value);
  }

  @override
  Future<void> deleteMany(Iterable<CareQueryId> keys) async {
    for (final k in keys) {
      await delete(k);
    }
  }

  @override
  Future<void> clear() async {
    _memory.clear();
    _memoryFetchedAt.clear();
    await _store.clearNamespace(_careNamespace);
  }

  void _remember(String key, List<CareEntity> value, DateTime fetchedAt) {
    _memory.put(key, value);
    _memoryFetchedAt[key] = fetchedAt;
  }

  /// False when the hot entry is past the TTL, or when the cache evicted the
  /// timestamp's companion value — treating an unknown time as stale sends the
  /// read to the database, which is the authority.
  bool _memoryIsFresh(String key) {
    final at = _memoryFetchedAt[key];
    return at != null && DateTime.now().toUtc().difference(at.toUtc()) < _ttl;
  }
}

/// Retained results survive provider rebuilds — deliberately NOT autoDispose,
/// or the retention would be discarded on the very rebuild it exists to
/// short-circuit.
///
/// Declared beside the implementation rather than with the other care
/// providers so the concrete `Drift*` name stays inside `infrastructure/`,
/// which is where the architecture test scopes it.
final localCareDirectoryDataSourceProvider = Provider<LocalCareDirectoryDataSource>(
  (ref) => DriftCareDirectoryDataSource(store: ref.watch(cacheStoreProvider)),
);
