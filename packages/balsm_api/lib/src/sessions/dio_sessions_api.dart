import 'package:dio/dio.dart';

import '../transport/api_exception.dart';
import '../transport/envelope.dart';
import 'responses.dart';
import 'sessions_api.dart';

class DioSessionsApi implements SessionsApi {
  const DioSessionsApi({required Dio dio}) : _dio = dio;

  final Dio _dio;

  @override
  Future<List<SessionResponse>> listSessions({CancelToken? cancelToken}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/sessions',
        cancelToken: cancelToken,
      );
      return unwrapEnvelopeList(res)
          .map((e) => SessionResponse.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<void> revokeSession(String sessionId, {CancelToken? cancelToken}) async {
    try {
      final res = await _dio.delete<Map<String, dynamic>>(
        '/sessions/$sessionId',
        cancelToken: cancelToken,
      );
      unwrapEnvelope(res);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<RevokeAllSessionsResponse> revokeAllSessions({CancelToken? cancelToken}) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/sessions/revoke-all',
        cancelToken: cancelToken,
      );
      return RevokeAllSessionsResponse.fromJson(unwrapEnvelope(res));
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
