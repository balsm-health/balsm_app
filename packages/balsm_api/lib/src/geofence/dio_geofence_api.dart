import 'package:dio/dio.dart' show CancelToken;

import '../api_routes.dart';
import '../transport/network_manager.dart';
import 'geofence_api.dart';
import 'responses.dart';

class DioGeofenceApi implements GeofenceApi {
  const DioGeofenceApi({required NetworkManager net}) : _net = net;

  final NetworkManager _net;

  @override
  Future<DeniedCountriesResponse> getDeniedCountries({CancelToken? cancelToken}) async {
    final res = await _net.get(ApiRoutes.geofence_denied_countries, cancelToken: cancelToken);
    // A decoded JSON object: its values are untyped until each field is read and checked.
    final body = res.data ?? const <String, dynamic>{};
    // Legacy tolerance: unwrap {data: {...}} but fall back to the flat body.
    final data = body['data'];
    final payload = data is Map<String, dynamic> ? data : body;
    return DeniedCountriesResponse.fromJson(payload);
  }
}
