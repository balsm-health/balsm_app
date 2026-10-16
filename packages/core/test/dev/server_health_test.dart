import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:balsm_api/balsm_api.dart' show ApiRoutes;
import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers with a fixed status, or throws a chosen transport failure.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter.status(this.statusCode,
      {this.body = const {
        'data': {'status': 'Healthy'}
      }})
      : error = null,
        cause = null;
  _StubAdapter.failure(this.error, {this.cause})
      : statusCode = 0,
        body = null;

  final int statusCode;
  final Object? body;
  final DioExceptionType? error;
  final Object? cause;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream, Future<void>? cancelFuture) async {
    lastRequest = options;
    if (error != null) {
      throw DioException(requestOptions: options, type: error!, error: cause);
    }
    return ResponseBody.fromString(
      body is String ? body! as String : jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [body is String ? 'text/html' : Headers.jsonContentType]
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

    test('carries every field of the health body, and the deployed version', () async {
      final adapter = _StubAdapter.status(200, body: {
        'status': 'Healthy',
        'ready': true,
        'version': '0.1.1.0',
        'uptime_seconds': 42,
        'not_ready_reason': null,
      });

      final result = await ServerHealthProbe(adapter: adapter).check('http://x') as ServerHealthy;

      expect(result.version, '0.1.1.0');
      expect(result.details, {
        'status': 'Healthy',
        'ready': true,
        'version': '0.1.1.0',
        'uptime_seconds': 42,
        'not_ready_reason': null,
      });
    });

    test('unwraps a body nested under data', () async {
      final result = await ServerHealthProbe(adapter: _StubAdapter.status(200)).check('http://x') as ServerHealthy;

      expect(result.details, {'status': 'Healthy'});
      expect(result.version, isNull);
    });

    test('a body that is not a JSON object gives no details', () async {
      // A proxy error page, not the API.
      final adapter = _StubAdapter.status(502, body: '<html>Bad Gateway</html>');

      final result = await ServerHealthProbe(adapter: adapter).check('http://x') as ServerHealthy;

      expect(result.details, isEmpty);
      expect(result.version, isNull);
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
        DioExceptionType.badCertificate: 'Bad TLS certificate',
      };

      for (final entry in cases.entries) {
        final result = await ServerHealthProbe(adapter: _StubAdapter.failure(entry.key)).check('http://x');

        expect(result, isA<ServerUnreachable>(), reason: '${entry.key}');
        expect((result as ServerUnreachable).reason, entry.value);
      }
    });

    test('names the three ways a connection error actually happens', () async {
      // These need different fixes, so collapsing them into one message hides
      // the only thing the developer wants to know. A hostname that does not
      // resolve is exactly how the Production preset fails today.
      Future<String> reasonFor(SocketException cause) async {
        final result = await ServerHealthProbe(
          adapter: _StubAdapter.failure(DioExceptionType.connectionError, cause: cause),
        ).check('http://x');
        return (result as ServerUnreachable).reason;
      }

      expect(
        await reasonFor(const SocketException('Failed host lookup: \'api.balsm.health\'')),
        'Host not found — check the URL',
      );
      expect(
        await reasonFor(const SocketException('Connection refused', osError: OSError('', 61))),
        'Connection refused — is the server running?',
      );
      expect(
        await reasonFor(const SocketException('Network is unreachable')),
        'Network unreachable',
      );
    });

    test('an unrecognised socket failure still reads sensibly', () async {
      final result = await ServerHealthProbe(
        adapter: _StubAdapter.failure(DioExceptionType.connectionError, cause: const SocketException('weird')),
      ).check('http://x');

      expect((result as ServerUnreachable).reason, 'Cannot reach server');
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
