import 'package:dio/dio.dart' show CancelToken;

import '../api_routes.dart';
import '../transport/envelope.dart';
import '../transport/network_manager.dart';
import 'disclosure_api.dart';
import 'requests.dart';

class DioDisclosureApi implements DisclosureApi {
  const DioDisclosureApi({required NetworkManager net}) : _net = net;

  final NetworkManager _net;

  @override
  Future<void> accept(AcceptDisclosureRequest request,
      {CancelToken? cancelToken}) async {
    final res = await _net.post(
      ApiRoutes.disclosure_accept,
      data: request.toJson(),
      cancelToken: cancelToken,
    );
    unwrapEnvelope(res);
  }
}
