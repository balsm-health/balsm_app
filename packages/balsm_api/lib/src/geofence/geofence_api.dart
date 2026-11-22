import 'package:dio/dio.dart' show CancelToken;

import '../../balsm_api.dart' show ApiException;
import '../transport/api_exception.dart' show ApiException;
import 'responses.dart';

/// Geofence endpoints (.NET shared/geofence).
/// Throws [ApiException] on transport errors.
/// Pass a [CancelToken] to abort the request.
abstract class GeofenceApi {
  /// GET /geofence/denied-countries
  Future<DeniedCountriesResponse> getDeniedCountries({CancelToken? cancelToken});
}
