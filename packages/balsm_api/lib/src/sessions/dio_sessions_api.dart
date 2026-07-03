import 'package:dio/dio.dart' show CancelToken;

import '../api_routes.dart';
import '../transport/envelope.dart';
import '../transport/network_manager.dart';
import 'responses.dart';
import 'sessions_api.dart';

class DioSessionsApi implements SessionsApi {
  const DioSessionsApi({required NetworkManager net}) : _net = net;

  final NetworkManager _net;

  @override
  Future<List<SessionResponse>> listSessions({CancelToken? cancelToken}) async {
    final res = await _net.get(ApiRoutes.sessions, cancelToken: cancelToken);
    return unwrapEnvelopeList(res)
        .map((e) => SessionResponse.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<void> revokeSession(String sessionId, {CancelToken? cancelToken}) async {
    final res = await _net.delete(ApiRoutes.session(sessionId), cancelToken: cancelToken);
    unwrapEnvelope(res);
  }

  @override
  Future<RevokeAllSessionsResponse> revokeAllSessions({CancelToken? cancelToken}) async {
    final res = await _net.post(ApiRoutes.sessions_revoke_all, cancelToken: cancelToken);
    return RevokeAllSessionsResponse.fromJson(unwrapEnvelope(res));
  }
}
