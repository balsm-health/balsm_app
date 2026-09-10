import 'package:balsm_api/balsm_api.dart' show CancelToken;
import 'package:latlong2/latlong.dart' hide Path;

import '../care_entity.dart';
import '../ports/care_directory_data_source.dart';
import '../ports/care_directory_repository.dart';

/// [CareDirectoryRepository] that answers from the local data source when it
/// can and the remote one when it must.
///
/// Read-through, not write-back: a miss fetches and retains, a hit returns
/// immediately without touching the network. The map re-queries on every
/// settled pan, so panning back over covered ground is the common case this
/// exists for.
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
  Future<List<CareEntity>> nearby(
    LatLng center,
    CareSearch search, {
    CancelToken? cancelToken,
  }) async {
    final key = careCacheKey(center, search);

    final retained = _local.read(key);
    if (retained != null) return retained;

    final fetched = await _remote.nearby(center, search, cancelToken: cancelToken);
    _local.write(key, fetched);
    return fetched;
  }
}
