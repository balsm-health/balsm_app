import 'package:balsm_api/balsm_api.dart' show CancelToken;
import 'package:latlong2/latlong.dart' hide Path;

import '../care_entity.dart';

/// Directory results plus where they came from.
///
/// Staleness travels with the data rather than being inferred in the UI from
/// connectivity: `onlineProvider` reports whether an interface is up, not
/// whether these particular rows are old. A captive-portal Wi-Fi would have the
/// UI call stale data fresh, and a brief interface flap would have it call fresh
/// data stale.
class CareResults {
  const CareResults({required this.entities, required this.stale});
  const CareResults.fresh(this.entities) : stale = false;

  final List<CareEntity> entities;

  /// True when these came from a retained row past its TTL, because the refetch
  /// failed for want of a connection.
  final bool stale;
}

/// The same, for map pins.
class CarePinResults {
  const CarePinResults({required this.pins, required this.stale});
  const CarePinResults.fresh(this.pins) : stale = false;

  final List<CarePin> pins;
  final bool stale;
}

/// Read-side repository for the nearby-care directory.
///
/// The one thing callers ask for: places near a point, narrowed by a search.
/// Whether that is answered from a local retained result or a network call is
/// this layer's decision, not the caller's — which is what lets the map screen
/// stay ignorant of caching entirely.
abstract interface class CareDirectoryRepository {
  /// Places near [center] matching [search].
  ///
  /// [center] is expected to be rounded by the caller (see `CareQueryId.of`);
  /// unrounded coordinates defeat both this layer's retention and the server's
  /// vary-by-query cache.
  Future<CareResults> nearby(LatLng center, CareSearch search, {CancelToken? cancelToken});

  /// Map pins for [search]. [noFloor] mirrors the `kFlagMapNoZoomFloor` dev
  /// flag and changes both the request and its cache key.
  Future<CarePinResults> pins(
    LatLng center,
    CareSearch search, {
    bool noFloor = false,
    CancelToken? cancelToken,
  });

  /// Full detail for one place. No staleness flag — a detail sheet opened from a
  /// stale pin is already covered by the map's notice.
  Future<CareEntity?> byId(String id, LatLng center, {CancelToken? cancelToken});
}
