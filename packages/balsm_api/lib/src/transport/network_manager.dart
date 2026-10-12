import 'package:dio/dio.dart';

import 'api_exception.dart';

/// Thin transport over a shared [Dio]: executes HTTP verbs and maps every
/// [DioException] (including cancellation) to a typed [ApiException].
///
/// Responsibility split: NetworkManager owns transport + error mapping;
/// typed `DioXxxApi` clients own request/response DTOs and envelope handling
/// (auth is flat, other areas use the `{data, error}` envelope). It therefore
/// stays envelope-agnostic and returns the raw decoded [Response].
class NetworkManager {
  const NetworkManager({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<Response<Map<String, dynamic>>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) =>
      _guard(() => _dio.get<Map<String, dynamic>>(
            path,
            queryParameters: queryParameters,
            cancelToken: cancelToken,
            onReceiveProgress: onReceiveProgress,
          ));

  Future<Response<Map<String, dynamic>>> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) =>
      _guard(() => _dio.post<Map<String, dynamic>>(
            path,
            data: data,
            queryParameters: queryParameters,
            cancelToken: cancelToken,
            onSendProgress: onSendProgress,
            onReceiveProgress: onReceiveProgress,
          ));

  Future<Response<Map<String, dynamic>>> put(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) =>
      _guard(() => _dio.put<Map<String, dynamic>>(
            path,
            data: data,
            queryParameters: queryParameters,
            cancelToken: cancelToken,
            onSendProgress: onSendProgress,
          ));

  Future<Response<Map<String, dynamic>>> patch(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) =>
      _guard(() => _dio.patch<Map<String, dynamic>>(
            path,
            data: data,
            queryParameters: queryParameters,
            cancelToken: cancelToken,
            onSendProgress: onSendProgress,
          ));

  Future<Response<Map<String, dynamic>>> delete(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) =>
      _guard(() => _dio.delete<Map<String, dynamic>>(
            path,
            data: data,
            queryParameters: queryParameters,
            cancelToken: cancelToken,
          ));

  Future<Response<Map<String, dynamic>>> _guard(
    Future<Response<Map<String, dynamic>>> Function() run,
  ) async {
    try {
      return await run();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
