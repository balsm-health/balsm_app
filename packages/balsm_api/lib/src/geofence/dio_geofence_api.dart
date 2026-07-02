import 'package:dio/dio.dart';

import '../transport/api_exception.dart';
import 'geofence_api.dart';
import 'responses.dart';

class DioGeofenceApi implements GeofenceApi {
  const DioGeofenceApi({required Dio dio}) : _dio = dio;

  final Dio _dio;

  @override
  Future<DeniedCountriesResponse> getDeniedCountries() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/geofence/denied-countries');
      final body = res.data ?? const <String, dynamic>{};
      // Legacy tolerance: unwrap {data: {...}} but fall back to the flat body.
      final data = body['data'];
      final payload = data is Map<String, dynamic> ? data : body;
      return DeniedCountriesResponse.fromJson(payload);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
