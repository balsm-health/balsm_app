import 'package:dio/dio.dart';

import '../transport/api_exception.dart';
import '../transport/envelope.dart';
import 'deletion_api.dart';
import 'responses.dart';

class DioDeletionApi implements DeletionApi {
  const DioDeletionApi({required Dio dio}) : _dio = dio;

  final Dio _dio;

  @override
  Future<DeletionIntakeResponse> requestIntake() async {
    try {
      final res = await _dio.post<Map<String, dynamic>>('/deletion/intake');
      return DeletionIntakeResponse.fromJson(unwrapEnvelope(res));
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<DeletionCancelResponse> cancel() async {
    try {
      final res = await _dio.post<Map<String, dynamic>>('/deletion/cancel');
      return DeletionCancelResponse.fromJson(unwrapEnvelope(res));
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
