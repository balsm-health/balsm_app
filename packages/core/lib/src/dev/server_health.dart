import 'dart:io';

import 'package:balsm_api/balsm_api.dart' show ApiRoutes;
import 'package:dio/dio.dart';

/// Outcome of one Dev Config connection check.
sealed class ServerHealthResult {
  const ServerHealthResult();
}

/// The server answered. [statusCode] is what it returned — 200 means healthy,
/// anything else means something is listening but unwell, which is worth telling
/// the developer apart from silence.
final class ServerHealthy extends ServerHealthResult {
  const ServerHealthy({required this.statusCode, required this.elapsed});

  final int statusCode;
  final Duration elapsed;

  bool get isOk => statusCode == 200;
}

/// No usable answer: timeout, DNS failure, refused connection, TLS error.
/// [reason] is short enough to sit on one line in the Dev Config row.
final class ServerUnreachable extends ServerHealthResult {
  const ServerUnreachable(this.reason);
  final String reason;
}

/// Probes a server's readiness endpoint.
///
/// Dev Config only, and deliberately its own client rather than the app's:
/// the developer is checking a base URL they have SELECTED, which is usually not
/// the one the app is currently pointed at, and the probe must not inherit auth
/// headers, retries, or interceptors that would mask what the server actually
/// said.
///
/// Never throws — every failure becomes a [ServerUnreachable] the row can render.
class ServerHealthProbe {
  const ServerHealthProbe({this.timeout = const Duration(seconds: 6), this.adapter});

  final Duration timeout;

  /// Test seam. Production leaves this null and gets dio's real adapter; a test
  /// supplies one so the probe's own behaviour — status mapping, elapsed time,
  /// failure descriptions — can be exercised without a server.
  final HttpClientAdapter? adapter;

  Future<ServerHealthResult> check(String baseUrl) async {
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: timeout,
      receiveTimeout: timeout,
      // Any status is an answer; only transport failure is unreachable.
      validateStatus: (_) => true,
    ));
    if (adapter != null) dio.httpClientAdapter = adapter!;

    final started = DateTime.now();
    try {
      final res = await dio.get<dynamic>(ApiRoutes.health);
      return ServerHealthy(
        statusCode: res.statusCode ?? 0,
        elapsed: DateTime.now().difference(started),
      );
    } on DioException catch (e) {
      return ServerUnreachable(_describe(e));
    } catch (_) {
      return const ServerUnreachable('Unexpected error');
    } finally {
      dio.close(force: true);
    }
  }

  // Short, developer-readable, and never the raw exception — a dio message can
  // carry the full URL and headers, which is noise in a one-line status.
  //
  // connectionError and unknown both wrap a SocketException, and the three cases
  // underneath them need different fixes: a name that does not resolve is a
  // wrong URL, a refused connection is a server that is not running, and
  // anything else is the network. Collapsing them into "Cannot reach server"
  // hides which one it is, which is the whole question the developer has.
  static String _describe(DioException e) => switch (e.type) {
        DioExceptionType.connectionTimeout => 'Connection timed out',
        DioExceptionType.receiveTimeout => 'Request timed out',
        DioExceptionType.sendTimeout => 'Request timed out',
        DioExceptionType.badCertificate => 'Bad TLS certificate',
        DioExceptionType.cancel => 'Cancelled',
        DioExceptionType.badResponse => 'Bad response',
        DioExceptionType.connectionError || DioExceptionType.unknown => _describeSocket(e.error),
        // Default rather than an exhaustive list: the packages in this
        // workspace do not all resolve the same dio minor, so a case added in
        // one version fails to compile in another. dio 5.10's transformTimeout
        // lands here.
        _ => 'Request failed',
      };

  static String _describeSocket(Object? error) {
    if (error is! SocketException) return 'Cannot reach server';

    final message = error.message.toLowerCase();
    if (message.contains('failed host lookup') || error.osError?.errorCode == 8) {
      return 'Host not found — check the URL';
    }
    if (error.osError?.errorCode == 61 || message.contains('refused')) {
      return 'Connection refused — is the server running?';
    }
    if (message.contains('network is unreachable') || error.osError?.errorCode == 51) {
      return 'Network unreachable';
    }
    return 'Cannot reach server';
  }
}
