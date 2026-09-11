import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:balsm_api/balsm_api.dart' show ApiRoutes;
import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers with a fixed status, or throws a chosen transport failure.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter.status(this.statusCode) : error = null;
  _StubAdapter.failure(this.error) : statusCode = 0;

  final int statusCode;
  final DioExceptionType? error;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream, Future<void>? cancelFuture) async {
    lastRequest = options;
    if (error != null) {
      throw DioException(requestOptions: options, type: error!);
    }
    return ResponseBody.fromString(
      jsonEncode({
        'data': {'status': 'Healthy'}
      }),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('ServerHealthProbe', () {
    test('a 200 is healthy and reports elapsed time', () async {
      final adapter = _StubAdapter.status(200);

      final result = await ServerHealthProbe(adapter: adapter).check('http://localhost:5050');

      expect(result, isA<ServerHealthy>());
      final healthy = result as ServerHealthy;
      expect(healthy.statusCode, 200);
      expect(healthy.isOk, isTrue);
      expect(healthy.elapsed, greaterThanOrEqualTo(Duration.zero));
    });

    test('probes the anonymous readiness route', () async {
      // Must be an endpoint reachable WITHOUT a session — the developer is
      // checking a server they are not signed in to.
      final adapter = _StubAdapter.status(200);

      await ServerHealthProbe(adapter: adapter).check('http://localhost:5050');

      expect(adapter.lastRequest!.path, ApiRoutes.health);
      expect(adapter.lastRequest!.headers.containsKey('Authorization'), isFalse);
    });

    test('a non-200 is reachable but NOT ok', () async {
      // Something is listening and unwell. That is different from silence, and
      // the row shows the code rather than collapsing both into "failed".
      final result = await ServerHealthProbe(adapter: _StubAdapter.status(503)).check('http://x');

      expect(result, isA<ServerHealthy>());
      expect((result as ServerHealthy).isOk, isFalse);
      expect(result.statusCode, 503);
    });

    test('transport failures map to short readable reasons', () async {
      final cases = {
        DioExceptionType.connectionTimeout: 'Connection timed out',
        DioExceptionType.receiveTimeout: 'Request timed out',
        DioExceptionType.connectionError: 'Cannot reach server',
        DioExceptionType.badCertificate: 'Bad TLS certificate',
      };

      for (final entry in cases.entries) {
        final result = await ServerHealthProbe(adapter: _StubAdapter.failure(entry.key)).check('http://x');

        expect(result, isA<ServerUnreachable>(), reason: '${entry.key}');
        expect((result as ServerUnreachable).reason, entry.value);
      }
    });

    test('never throws, whatever the transport does', () async {
      // The Dev Config row has no error state beyond "fail" — an exception
      // escaping here would take the whole overlay down.
      for (final type in DioExceptionType.values) {
        final result = await ServerHealthProbe(adapter: _StubAdapter.failure(type)).check('http://x');
        expect(result, isA<ServerUnreachable>());
      }
    });
  });
}
