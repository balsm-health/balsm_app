import 'package:dio/dio.dart';

import '../transport/api_exception.dart';
import '../transport/envelope.dart';
import 'account_api.dart';
import 'requests.dart';
import 'responses.dart';

class DioAccountApi implements AccountApi {
  const DioAccountApi({required Dio dio}) : _dio = dio;

  final Dio _dio;

  @override
  Future<AccountSelfResponse?> getSelf({CancelToken? cancelToken}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/account/self',
        cancelToken: cancelToken,
      );
      final data = unwrapEnvelope(res);
      if (data.isEmpty) return null;
      return AccountSelfResponse.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<ClaimHandleResponse> claimHandle(ClaimHandleRequest request,
      {CancelToken? cancelToken}) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/account/handle/claim',
        data: request.toJson(),
        cancelToken: cancelToken,
      );
      return ClaimHandleResponse.fromJson(unwrapEnvelope(res));
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<void> changeLanguage(ChangeLanguageRequest request,
      {CancelToken? cancelToken}) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/account/language',
        data: request.toJson(),
        cancelToken: cancelToken,
      );
      unwrapEnvelope(res);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<void> changeCountry(ChangeCountryRequest request,
      {CancelToken? cancelToken}) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/account/country',
        data: request.toJson(),
        cancelToken: cancelToken,
      );
      unwrapEnvelope(res);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<HandleAvailabilityResponse> checkHandleAvailability(String handle,
      {CancelToken? cancelToken}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/account/handle/available',
        queryParameters: {'handle': handle},
        cancelToken: cancelToken,
      );
      return HandleAvailabilityResponse.fromJson(unwrapEnvelope(res));
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
