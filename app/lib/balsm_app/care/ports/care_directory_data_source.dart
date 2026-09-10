import 'package:balsm_api/balsm_api.dart' show CancelToken;
import 'package:latlong2/latlong.dart' hide Path;

import '../care_entity.dart';

/// Where directory results come from over the network.
///
/// Pure contract — no transport technology leaks here. The dio-backed
/// implementation lives in `infrastructure/` and is bound via
/// `remoteCareDirectoryDataSourceProvider`.
///
/// Returns domain [CareEntity] values, not wire DTOs: mapping the API's
/// nullable fields onto the domain's empty-string convention is this layer's
/// job, so nothing above it needs to know the wire shape.
abstract interface class RemoteCareDirectoryDataSource {
  /// Places near [center], narrowed by [search]. Distance-sorted, capped
  /// server-side at the nearest [kCareResultLimit].
  ///
  /// [cancelToken] lets a superseded request be abandoned — panning fires a
  /// query per settled gesture, so in-flight requests are routinely obsolete
  /// before they land.
  Future<List<CareEntity>> nearby(
    LatLng center,
    CareSearch search, {
    CancelToken? cancelToken,
  });
}

/// Locally retained directory results.
///
/// Not persistence in the PHI sense — the directory is public reference data,
/// so this is purely a bandwidth optimisation and may be discarded at any time.
/// Implementations must be safe to call on every query.
abstract interface class LocalCareDirectoryDataSource {
  /// Retained result for [key], or null when absent or stale.
  List<CareEntity>? read(String key);

  /// Retains [entities] under [key]. Implementations bound what they keep.
  void write(String key, List<CareEntity> entities);

  /// Drops everything retained.
  void clear();
}
