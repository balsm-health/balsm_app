import 'package:dio/dio.dart' show CancelToken;

import '../api_routes.dart';
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
}
