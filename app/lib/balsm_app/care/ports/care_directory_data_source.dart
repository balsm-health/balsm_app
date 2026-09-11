import 'package:balsm_api/balsm_api.dart' show CancelToken;
import 'package:core/core.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../care_entity.dart';
import 'care_query_id.dart';

/// Where directory results come from over the network.
///
/// Deliberately NOT a core [DataSource]: that contract is the base marker for
/// *local* data sources — CRUD over records this device owns. A remote search
/// is neither local nor CRUD (there is no `put`, no `delete`, and the key is
/// derived from the query rather than identifying a stored row), so forcing it
/// into that shape would mean implementing seven methods that throw.
///
/// Returns domain [CareEntity] values, not wire DTOs: mapping the API's
/// nullable fields — one name per place, no hours, no ratings — onto the
/// domain's conventions is this layer's job, so nothing above it knows the wire
/// shape.
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

/// Locally retained directory results, keyed by the query that produced them.
///
/// A core [DataSource]: unscoped, because the directory is public reference
/// data with no partition — it belongs to no profile and no account, unlike the
/// PHI sources that use [ProfileDataSource] / [UserDataSource]. Nothing stored
/// here is PHI, which is also why it need not participate in backup or wipe.
///
/// Retention policy — bounded size, TTL — is the implementation's own, exactly
/// as the base contract intends: policies are not part of the generic shape.
abstract class LocalCareDirectoryDataSource extends DataSource<CareQueryId, List<CareEntity>> {}
