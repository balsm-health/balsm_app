import 'dart:convert';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import 'phi_leak_interceptor.dart';

/// Debug-only Dio interceptor that logs each request/response to the dev
/// console (`dart:developer.log`, tag `balsm.http`).
///
/// Each request prints a copy-pasteable `curl`, but a SAFE one: sensitive
/// headers (`Authorization`, `Cookie`, `X-Dev-Key`, …) are redacted to
/// `<redacted>` and the body is the PHI-scrubbed copy — so it is intentionally
/// NOT directly runnable for auth/PHI endpoints (swap in your own token /
/// allowlist fields to replay).
///
/// PHI/secrets: it NEVER logs a raw header value or a raw body. Request bodies
/// come from the PHI-scrubbed copy [PhiLeakInterceptor] stashes in
/// `options.extra['phi_safe_body']`; response bodies are scrubbed here the same
/// way. Add it AFTER [PhiLeakInterceptor] so the scrubbed copy already exists.
class HttpLogInterceptor extends Interceptor {
  const HttpLogInterceptor();

  static const _name = 'balsm.http';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra['_log_ts'] = DateTime.now().microsecondsSinceEpoch;
    developer.log(
      '→ ${options.method} ${options.uri}\n${_curl(options)}',
      name: _name,
      level: 700,
    );
    handler.next(options);
  }

  /// A copy-pasteable curl with sensitive headers redacted and the PHI-scrubbed
  /// body. Headers here are what's set at request time; the bearer token is
  /// added by a later interceptor and never reaches this log.
  String _curl(RequestOptions o) {
    final parts = <String>["curl -X ${o.method} '${o.uri}'"];
    o.headers.forEach((k, v) {
      parts.add("-H '$k: ${_sensitive(k) ? '<redacted>' : v}'");
    });
    final body = o.extra['phi_safe_body'];
    if (body is Map) {
      String encoded;
      try {
        encoded = jsonEncode(body);
      } catch (_) {
        encoded = body.toString();
      }
      parts.add("-d '$encoded'");
    }
    return parts.join(" \\\n  ");
  }

  static bool _sensitive(String key) => const {
        'authorization',
        'cookie',
        'proxy-authorization',
        'x-dev-key',
        'x-api-key',
      }.contains(key.toLowerCase());

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final o = response.requestOptions;
    developer.log(
      '← ${response.statusCode} ${o.method} ${o.uri}${_elapsed(o)}'
      '${_body(response.data)}',
      name: _name,
      level: 800,
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final o = err.requestOptions;
    final res = err.response;
    developer.log(
      '✗ ${res?.statusCode ?? err.type.name} ${o.method} ${o.uri}${_elapsed(o)}'
      '${res == null ? '' : _body(res.data)}',
      name: _name,
      level: 1000,
      error: err.message,
    );
    handler.next(err);
  }

  String _body(Object? data) => data is Map ? '\n  body: ${PhiLeakInterceptor.scrubForTelemetry(data)}' : '';

  String _elapsed(RequestOptions o) {
    final start = o.extra['_log_ts'];
    if (start is! int) return '';
    final ms = (DateTime.now().microsecondsSinceEpoch - start) / 1000;
    return ' (${ms.toStringAsFixed(0)}ms)';
  }
}
