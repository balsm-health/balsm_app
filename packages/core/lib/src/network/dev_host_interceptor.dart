import 'dart:developer' as developer;

import 'package:dio/dio.dart';

/// Re-finds the dev server when a request cannot reach it, and replays that
/// request once against the machine it found.
///
/// The address of a laptop on the desk changes — a new Wi-Fi network, a lease
/// renewed overnight, the server restarted somewhere else. Without this, the
/// app holds the address it resolved at startup until it is relaunched, which
/// is the rebuild this whole mechanism exists to avoid.
///
/// Only connection failures qualify. A 500, a timeout mid-response, a refused
/// TLS handshake — all of those are a server that WAS found and is answering
/// badly, and re-pointing the app at a different machine would hide the real
/// failure.
class DevHostInterceptor extends Interceptor {
  DevHostInterceptor({required this.rediscover, required this.retry});

  /// Looks the host up again. Returns the new base URL, or null when the host
  /// did not change or the lookup found nothing.
  final Future<String?> Function() rediscover;

  /// Sends [options] again, against whatever base URL the client now holds.
  final Future<Response<dynamic>> Function(RequestOptions options) retry;

  /// Guards against a storm: a screen that fires six requests at once must
  /// sweep the subnet once, not six times.
  Future<String?>? _inFlight;

  static const _retried = 'balsm.dev_host_retried';

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final connectionFailed =
        err.type == DioExceptionType.connectionError || err.type == DioExceptionType.connectionTimeout;
    // One retry per request. A second failure is a real one.
    if (!connectionFailed || err.requestOptions.extra.containsKey(_retried)) {
      return handler.next(err);
    }

    developer.log(
      'cannot reach ${err.requestOptions.baseUrl} — looking for the server again',
      name: 'balsm.devhost',
    );
    final found = await (_inFlight ??= rediscover().whenComplete(() => _inFlight = null));
    if (found == null) return handler.next(err);
    developer.log('retrying ${err.requestOptions.path} against $found', name: 'balsm.devhost');

    final options = err.requestOptions
      ..baseUrl = found
      ..extra[_retried] = true;
    try {
      handler.resolve(await retry(options));
    } on DioException catch (e) {
      handler.next(e);
    } catch (_) {
      handler.next(err);
    }
  }
}
