import 'package:dio/dio.dart' show CancelToken;

import 'responses.dart';

/// Geofence endpoints (.NET shared/geofence).
/// Throws [ApiException] on transport errors.
/// Pass a [CancelToken] to abort the request.
abstract class GeofenceApi {
  /// GET /geofence/denied-countries
  Future<DeniedCountriesResponse> getDeniedCountries({CancelToken? cancelToken});
}
