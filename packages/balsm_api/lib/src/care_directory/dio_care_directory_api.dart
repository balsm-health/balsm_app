import 'package:dio/dio.dart' show CancelToken;

import '../api_routes.dart';
import '../transport/api_exception.dart';
import '../transport/envelope.dart';
import '../transport/network_manager.dart';
import 'care_directory_api.dart';
import 'requests.dart';
import 'responses.dart';

class DioCareDirectoryApi implements CareDirectoryApi {
  const DioCareDirectoryApi({required NetworkManager net}) : _net = net;

  final NetworkManager _net;

  @override
  Future<List<CareEntityResponse>> nearby(NearbyCareQuery query, {CancelToken? cancelToken}) async {
    final res = await _net.get(
      ApiRoutes.care_entities,
      queryParameters: query.toQueryParameters(),
      cancelToken: cancelToken,
    );
    return unwrapEnvelopeList(res)
        .map((e) => CareEntityResponse.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<List<CarePinResponse>> pins(CarePinsQuery query, {CancelToken? cancelToken}) async {
    final res = await _net.get(
      ApiRoutes.care_pins,
      queryParameters: query.toQueryParameters(),
      cancelToken: cancelToken,
    );
    return unwrapEnvelopeList(res)
        .map((e) => CarePinResponse.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<CareEntityResponse?> byId(String id, {double? lat, double? lng, CancelToken? cancelToken}) async {
    try {
      final res = await _net.get(
        ApiRoutes.careEntity(id),
        queryParameters: {
          if (lat != null) 'lat': lat,
          if (lng != null) 'lng': lng,
        },
        cancelToken: cancelToken,
      );
      return CareEntityResponse.fromJson(unwrapEnvelope(res));
    } on ApiException catch (e) {
      // A place that has left the directory is an absence, not a failure — the
      // caller shows "no longer listed" rather than an error.
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }
}
