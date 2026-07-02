import 'package:dio/dio.dart';

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

  factory BalsmApiClient.create({required String baseUrl}) {
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
    ));
    dio.interceptors.add(PhiLeakInterceptor());
    return BalsmApiClient(dio: dio);
  }
}
