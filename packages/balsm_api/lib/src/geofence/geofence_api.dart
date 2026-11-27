import 'package:dio/dio.dart' show CancelToken;

import '../../balsm_api.dart' show ApiException;
import '../transport/api_exception.dart' show ApiException;
import 'responses.dart';

/// Geofence endpoints (.NET shared/geofence).
/// Throws [ApiException] on transport errors.
/// Pass a [CancelToken] to abort the request.
// Port interface; the real client and the test fakes are swapped per environment.
// ignore: one_member_abstracts
abstract class GeofenceApi {
  /// GET /geofence/denied-countries
  Future<DeniedCountriesResponse> getDeniedCountries({CancelToken? cancelToken});
}
