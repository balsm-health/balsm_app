import 'package:dio/dio.dart' show CancelToken;

import 'requests.dart';
import 'responses.dart';

/// Nearby health-place directory (hospitals, clinics, pharmacies, labs, scan
/// centers, medical stores). Non-PHI, Balsm-owned reference data.
abstract class CareDirectoryApi {
  /// GET /care/entities — places near [query].lat/lng, distance-sorted.
  Future<List<CareEntityResponse>> nearby(NearbyCareQuery query, {CancelToken? cancelToken});
}
