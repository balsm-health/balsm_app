/// One cached payload and when it was fetched.
///
/// Freshness is a question the caller asks with its own TTL rather than a
/// property of the row: the same row is fresh enough for one consumer and
/// stale for another.
class CacheRow {
  const CacheRow({
    required this.key,
    required this.payload,
    required this.fetchedAt,
  });

  final String key;

  /// Opaque to the store — JSON, by every current convention, but the store
  /// neither parses nor validates it.
  final String payload;

  final DateTime fetchedAt;

  bool isFresh(Duration ttl) => DateTime.now().toUtc().difference(fetchedAt.toUtc()) < ttl;
}
