import 'package:dio/dio.dart';

import 'http_log_interceptor.dart';
import 'phi_leak_interceptor.dart';

/// Owns the shared [Dio] instance for all Balsm API areas.
///
/// Pure Dart on purpose: server-preset persistence, flavors, and DI live in
/// the app's `core` package, which drives [baseUrl] at runtime.
class BalsmApiClient {
  BalsmApiClient({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Dio get dio => _dio;

  String get baseUrl => _dio.options.baseUrl;

  set baseUrl(String value) => _dio.options.baseUrl = value;

  /// [logRequests] adds a console request/response logger (debug builds only —
  /// pass `kDebugMode`). It logs method/URL/status/timing + PHI-scrubbed bodies,
  /// never headers or raw payloads. Added after [PhiLeakInterceptor] so the
  /// scrubbed body copy already exists.
  factory BalsmApiClient.create({
    required String baseUrl,
    bool logRequests = false,
  }) {
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
    ));
    dio.interceptors.add(PhiLeakInterceptor());
    if (logRequests) dio.interceptors.add(const HttpLogInterceptor());
    return BalsmApiClient(dio: dio);
  }
}
