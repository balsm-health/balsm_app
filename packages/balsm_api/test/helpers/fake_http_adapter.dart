import 'dart:typed_data';

import 'package:balsm_api/balsm_api.dart';
import 'package:dio/dio.dart';

/// Canned-response HttpClientAdapter for exercising Dio impls without a
/// network. Records every request for assertion.
class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

/// JSON 200/xx response shorthand.
ResponseBody jsonResponse(String json, {int status = 200, Map<String, List<String>>? headers}) =>
    ResponseBody.fromString(
      json,
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        ...?headers,
      },
    );

/// Dio wired to a [FakeHttpAdapter], mirroring BalsmApiClient BaseOptions.
Dio fakeDio(FakeHttpAdapter adapter) {
  final dio = Dio(BaseOptions(
    baseUrl: 'https://api.test',
    headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
    // Surface non-2xx as DioException like production defaults.
  ));
  dio.httpClientAdapter = adapter;
  return dio;
}

/// [NetworkManager] backed by a [FakeHttpAdapter] — what area-client tests inject.
NetworkManager fakeNet(FakeHttpAdapter adapter) =>
    NetworkManager(dio: fakeDio(adapter));
