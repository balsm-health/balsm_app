import 'responses.dart';

/// Geofence endpoints (.NET shared/geofence).
/// Throws [ApiException] on transport errors.
abstract class GeofenceApi {
  /// GET /geofence/denied-countries
  Future<DeniedCountriesResponse> getDeniedCountries();
}
