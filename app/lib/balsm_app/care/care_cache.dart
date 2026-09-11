import 'care_entity.dart';

/// Bounded, time-limited cache of care-directory results.
///
/// The map re-queries on every settled pan, so panning back over ground already
/// covered refetches it — on a connection where that costs real money. Directory
/// rows change only when an import runs, so a short-lived cache is safe.
///
/// Keyed on a ROUNDED centre (see `CareQueryId.of`): a few metres of drift must
/// not miss. The same rounding is what lets the server's output cache, which
/// varies by query string, hit as well.
class CareDirectoryCache {
  CareDirectoryCache({
    this.maxEntries = 32,
    this.ttl = const Duration(minutes: 10),
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  /// Cap on retained result sets. Each holds at most [kCareResultLimit] entities,
  /// so this bounds worst-case retention at a few thousand small objects.
  final int maxEntries;

  /// How long a result stays usable.
  final Duration ttl;

  final DateTime Function() _now;

  /// Insertion-ordered, so the first key is the least recently used.
  final Map<String, _CacheEntry> _entries = {};

  /// Returns a cached result, or null when absent or expired. A hit is promoted
  /// to most-recently-used.
  List<CareEntity>? get(String key) {
    final entry = _entries.remove(key);
    if (entry == null) return null;

    if (_now().difference(entry.storedAt) > ttl) return null;

    _entries[key] = entry;
    return entry.value;
  }

  void put(String key, List<CareEntity> value) {
    _entries.remove(key);
    _entries[key] = _CacheEntry(value, _now());

    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  void remove(String key) => _entries.remove(key);

  void clear() => _entries.clear();

  /// Every unexpired retained result. Expired entries are dropped on the way
  /// out so a caller never sees one.
  List<List<CareEntity>> get values {
    final cutoff = _now();
    _entries.removeWhere((_, e) => cutoff.difference(e.storedAt) > ttl);
    return _entries.values.map((e) => e.value).toList(growable: false);
  }

  int get length => _entries.length;
}

class _CacheEntry {
  const _CacheEntry(this.value, this.storedAt);
  final List<CareEntity> value;
  final DateTime storedAt;
}
