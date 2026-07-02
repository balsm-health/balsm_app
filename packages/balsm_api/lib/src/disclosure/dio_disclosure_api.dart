import 'package:dio/dio.dart';

import '../transport/api_exception.dart';
import '../transport/envelope.dart';
import 'disclosure_api.dart';
import 'requests.dart';

class DioDisclosureApi implements DisclosureApi {
  const DioDisclosureApi({required Dio dio}) : _dio = dio;

  final Dio _dio;

  @override
  Future<void> accept(AcceptDisclosureRequest request,
      {CancelToken? cancelToken}) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/disclosure/accept',
        data: request.toJson(),
        cancelToken: cancelToken,
      );
      unwrapEnvelope(res);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
