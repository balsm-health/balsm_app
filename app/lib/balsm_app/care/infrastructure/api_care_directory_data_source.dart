import 'package:balsm_api/balsm_api.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../care_entity.dart';
import '../ports/care_directory_data_source.dart';

/// [RemoteCareDirectoryDataSource] over the care-directory API.
///
/// Owns the wire-to-domain mapping, so the nullable shape of the response —
/// Overture supplies one name per place, no opening hours and no ratings —
/// stops here rather than propagating upward.
class ApiCareDirectoryDataSource implements RemoteCareDirectoryDataSource {
  const ApiCareDirectoryDataSource(this._api);

  final CareDirectoryApi _api;

  @override
  Future<List<CareEntity>> nearby(
    LatLng center,
    CareSearch search, {
    CancelToken? cancelToken,
  }) async {
    final text = search.text.trim();
    final res = await _api.nearby(
      NearbyCareQuery(
        lat: center.latitude,
        lng: center.longitude,
        radiusKm: search.radiusKm,
        type: search.wireType,
        query: text.isEmpty ? null : text,
        limit: kCareResultLimit,
      ),
      cancelToken: cancelToken,
    );

    return res.map(CareEntity.fromResponse).toList(growable: false);
  }
}
