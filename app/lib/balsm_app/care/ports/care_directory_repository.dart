import 'package:balsm_api/balsm_api.dart' show CancelToken;
import 'package:latlong2/latlong.dart' hide Path;

import '../care_entity.dart';

/// Read-side repository for the nearby-care directory.
///
/// The one thing callers ask for: places near a point, narrowed by a search.
/// Whether that is answered from a local retained result or a network call is
/// this layer's decision, not the caller's — which is what lets the map screen
/// stay ignorant of caching entirely.
abstract interface class CareDirectoryRepository {
  /// Places near [center] matching [search].
  ///
  /// [center] is expected to be rounded by the caller (see [careCacheKey]);
  /// unrounded coordinates defeat both this layer's retention and the server's
  /// vary-by-query cache.
  Future<List<CareEntity>> nearby(
    LatLng center,
    CareSearch search, {
    CancelToken? cancelToken,
  });
}
