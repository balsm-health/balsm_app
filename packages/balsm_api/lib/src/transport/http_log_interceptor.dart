import 'dart:convert';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';

/// Debug-only Dio interceptor that logs the FULL request and response —
/// method, URL, every header, and the complete body — to the dev console
/// (`dart:developer.log`, tag `balsm.http`). Nothing is scrubbed or redacted.
///
/// DEBUG BUILDS ONLY. It is wired in `BalsmApiController.create` behind
/// `kDebugMode`, and added AFTER the auth interceptor so the outgoing bearer
/// token is visible in the request log. It prints PHI and access/refresh
/// tokens verbatim — NEVER enable it in a release build.
class HttpLogInterceptor extends Interceptor {
  const HttpLogInterceptor();

  static const _name = 'balsm.http';
  static const _encoder = JsonEncoder.withIndent('  ');

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra['_log_ts'] = DateTime.now().microsecondsSinceEpoch;
    final b = StringBuffer('→ ${options.method} ${options.uri}');
    _headers(b, options.headers);
    _body(b, options.data);
    developer.log(b.toString(), name: _name, level: 700);
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final o = response.requestOptions;
    final b = StringBuffer('← ${response.statusCode} ${o.method} ${o.uri}${_elapsed(o)}');
    _headers(b, response.headers.map);
    _body(b, response.data);
    developer.log(b.toString(), name: _name, level: 800);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final o = err.requestOptions;
    final res = err.response;
    final b = StringBuffer('✗ ${res?.statusCode ?? err.type.name} ${o.method} ${o.uri}${_elapsed(o)}');
    if (res != null) {
      _headers(b, res.headers.map);
      _body(b, res.data);
    }
    developer.log(b.toString(), name: _name, level: 1000, error: err.message);
    handler.next(err);
  }

  /// Appends every header verbatim (string or `List<String>` values).
  void _headers(StringBuffer b, Map<String, dynamic> headers) {
    if (headers.isEmpty) return;
    b.write('\n  headers:');
    headers.forEach((k, v) => b.write('\n    $k: ${v is List ? v.join(', ') : v}'));
  }

  /// Appends the full body, pretty-printed for maps/lists, indented under the
  /// log line. No fields are omitted.
  void _body(StringBuffer b, Object? data) {
    if (data == null) return;
    String out;
    if (data is Map || data is List) {
      try {
        out = _encoder.convert(data);
      } catch (_) {
        out = data.toString();
      }
    } else {
      out = data.toString();
    }
    if (out.isEmpty) return;
    b.write('\n  body: ');
    b.write(out.replaceAll('\n', '\n  '));
  }

  String _elapsed(RequestOptions o) {
    final start = o.extra['_log_ts'];
    if (start is! int) return '';
    final ms = (DateTime.now().microsecondsSinceEpoch - start) / 1000;
    return ' (${ms.toStringAsFixed(0)}ms)';
  }
}
