import 'package:dio/dio.dart' show CancelToken;

import '../api_routes.dart';
import '../transport/envelope.dart';
import '../transport/network_manager.dart';
import 'deletion_api.dart';
import 'responses.dart';

class DioDeletionApi implements DeletionApi {
  const DioDeletionApi({required NetworkManager net}) : _net = net;

  final NetworkManager _net;

  @override
  Future<DeletionIntakeResponse> requestIntake({CancelToken? cancelToken}) async {
    final res = await _net.post(ApiRoutes.deletion_intake, cancelToken: cancelToken);
    return DeletionIntakeResponse.fromJson(unwrapEnvelope(res));
  }

  @override
  Future<DeletionCancelResponse> cancel({CancelToken? cancelToken}) async {
    final res = await _net.post(ApiRoutes.deletion_cancel, cancelToken: cancelToken);
    return DeletionCancelResponse.fromJson(unwrapEnvelope(res));
  }
}
