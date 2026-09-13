import 'package:balsm_api/balsm_api.dart' show CancelToken, isOfflineError;
import 'package:latlong2/latlong.dart' hide Path;

import '../care_entity.dart';
import '../ports/care_directory_data_source.dart';
import '../ports/care_directory_repository.dart';
import '../ports/care_query_id.dart';

/// [CareDirectoryRepository] that answers from the local data source when it
/// can and the remote one when it must.
///
/// Read-through, not write-back: a fresh hit returns immediately without
/// touching the network. The map re-queries on every settled pan, so panning
/// back over covered ground is the common case this exists for.
///
/// An expired hit attempts a refetch. If that refetch fails for want of a
/// connection, the expired value is returned marked `stale` — a map with
/// week-old pins beats a blank one, provided it says so. Any other failure
/// propagates: serving stale data for a 500 would hide the bug forever.
///
/// A failed remote call is NOT retained — an error must not be cached as if it
/// were an answer, or a transient network blip would look like an empty area
/// for the rest of the TTL.
class CachingCareDirectoryRepository implements CareDirectoryRepository {
  const CachingCareDirectoryRepository({
    required RemoteCareDirectoryDataSource remote,
    required LocalCareDirectoryDataSource local,
  })  : _remote = remote,
        _local = local;

  final RemoteCareDirectoryDataSource _remote;
  final LocalCareDirectoryDataSource _local;

  @override
  Future<CareResults> nearby(LatLng center, CareSearch search, {CancelToken? cancelToken}) async {
    final key = CareQueryId.of(center, search);
    final hit = await _local.findRow(key);
    if (hit != null && !hit.expired) return CareResults.fresh(hit.value);

    try {
      final fetched = await _remote.nearby(center, search, cancelToken: cancelToken);
      await _local.put(key, fetched);
      return CareResults.fresh(fetched);
    } catch (e) {
      if (hit != null && isOfflineError(e)) {
        return CareResults(entities: hit.value, stale: true);
      }
      rethrow;
    }
  }

  @override
  Future<CarePinResults> pins(
    LatLng center,
    CareSearch search, {
    bool noFloor = false,
    CancelToken? cancelToken,
  }) async {
    final key = CarePinQueryId.of(center, search, noFloor: noFloor);
    final hit = await _local.findPins(key);
    if (hit != null && !hit.expired) return CarePinResults.fresh(hit.value);

    try {
      final fetched = await _remote.pins(center, search, noFloor: noFloor, cancelToken: cancelToken);
      await _local.putPins(key, fetched);
      return CarePinResults.fresh(fetched);
    } catch (e) {
      if (hit != null && isOfflineError(e)) {
        return CarePinResults(pins: hit.value, stale: true);
      }
      rethrow;
    }
  }

  @override
  Future<CareEntity?> byId(String id, LatLng center, {CancelToken? cancelToken}) async {
    final key = CareEntityId.of(id);
    final hit = await _local.findEntity(key);
    if (hit != null) return hit;

    try {
      final fetched = await _remote.byId(id, center, cancelToken: cancelToken);
      if (fetched != null) await _local.putEntity(key, fetched);
      return fetched;
    } catch (e) {
      // Nothing retained and no connection: the sheet shows its own empty
      // state, which is also what a place that has left the directory looks
      // like. An error dialog would be worse and no more informative.
      if (isOfflineError(e)) return null;
      rethrow;
    }
  }
}
