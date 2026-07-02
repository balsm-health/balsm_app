import 'package:dio/dio.dart';

import '../transport/api_exception.dart';
import '../transport/envelope.dart';
import 'responses.dart';
import 'sessions_api.dart';

class DioSessionsApi implements SessionsApi {
  const DioSessionsApi({required Dio dio}) : _dio = dio;

  final Dio _dio;

  @override
  Future<List<SessionResponse>> listSessions() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/sessions');
      return unwrapEnvelopeList(res)
          .map((e) => SessionResponse.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<void> revokeSession(String sessionId) async {
    try {
      final res = await _dio.delete<Map<String, dynamic>>('/sessions/$sessionId');
      unwrapEnvelope(res);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<RevokeAllSessionsResponse> revokeAllSessions() async {
    try {
      final res = await _dio.post<Map<String, dynamic>>('/sessions/revoke-all');
      return RevokeAllSessionsResponse.fromJson(unwrapEnvelope(res));
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
