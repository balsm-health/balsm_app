import 'package:dio/dio.dart' show CancelToken;

import '../transport/envelope.dart';
import '../transport/network_manager.dart';
import 'responses.dart';
import 'sessions_api.dart';

class DioSessionsApi implements SessionsApi {
  const DioSessionsApi({required NetworkManager net}) : _net = net;

  final NetworkManager _net;

  @override
  Future<List<SessionResponse>> listSessions({CancelToken? cancelToken}) async {
    final res = await _net.get('/sessions', cancelToken: cancelToken);
    return unwrapEnvelopeList(res)
        .map((e) => SessionResponse.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<void> revokeSession(String sessionId, {CancelToken? cancelToken}) async {
    final res = await _net.delete('/sessions/$sessionId', cancelToken: cancelToken);
    unwrapEnvelope(res);
  }

  @override
  Future<RevokeAllSessionsResponse> revokeAllSessions({CancelToken? cancelToken}) async {
    final res = await _net.post('/sessions/revoke-all', cancelToken: cancelToken);
    return RevokeAllSessionsResponse.fromJson(unwrapEnvelope(res));
  }
}
