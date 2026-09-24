import 'dart:convert';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';

/// Debug-only Dio interceptor that logs the request and response — method,
/// URL, headers, and body — to the dev console (`dart:developer.log`, tag
/// `balsm.http`), with credentials replaced.
///
/// Credentials are redacted because this log is made to be pasted: into a
/// terminal, a bug report, a chat with whoever is helping. A bearer token, a
/// password, or a one-time code that reaches any of those places has left the
/// device, and none of them are needed to debug the request that carried them.
/// Everything else prints in full, including PHI — so this is still DEBUG
/// BUILDS ONLY. It is wired in `BalsmApiController.create` behind
/// `kDebugMode`.
class HttpLogInterceptor extends Interceptor {
  const HttpLogInterceptor();

  static const _name = 'balsm.http';
  static const _encoder = JsonEncoder.withIndent('  ');

  /// Stands in for any value that must not be printed.
  static const redacted = '••• redacted •••';

  /// Body keys whose value is a credential. Matched case-insensitively and by
  /// containment, so `new_password`, `refreshToken` and `id_token` are covered
  /// without listing every spelling the API uses.
  static const _secretKeyParts = [
    'password',
    'token',
    'secret',
    'code',
    'authorization',
    'cookie',
  ];

  static bool _isSecret(Object? key) {
    final k = key.toString().toLowerCase();
    return _secretKeyParts.any(k.contains);
  }

  /// [data] with every credential value replaced.
  ///
  /// Maps and lists are walked; anything else is returned untouched rather
  /// than guessed at — a redactor that mangles an unrecognised body makes the
  /// log useless for the case you most need it.
  static Object? redactBody(Object? data) {
    if (data is Map) {
      return {
        for (final entry in data.entries) entry.key: _isSecret(entry.key) ? redacted : redactBody(entry.value),
      };
    }
    if (data is List) return [for (final item in data) redactBody(item)];
    return data;
  }

  /// [headers] with credential values replaced, keeping the auth scheme —
  /// knowing a request went out as `Bearer` with no token attached is often
  /// the whole answer.
  static Map<String, dynamic> redactHeaders(Map<String, dynamic> headers) => {
        for (final entry in headers.entries)
          entry.key: !_isSecret(entry.key)
              ? entry.value
              : entry.key.toLowerCase().contains('authorization')
                  ? _schemeOnly(entry.value)
                  : redacted,
      };

  /// `Bearer <token>` → `Bearer •••`. Only for Authorization, where the scheme
  /// is the useful half; a cookie has no such split and is replaced whole.
  static String _schemeOnly(Object? value) {
    final raw = value is List ? value.join(', ') : value.toString();
    final space = raw.indexOf(' ');
    return space > 0 ? '${raw.substring(0, space)} $redacted' : redacted;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra['_log_ts'] = DateTime.now().microsecondsSinceEpoch;
    final b = StringBuffer('→ ${options.method} ${options.uri}');
    _headers(b, redactHeaders(options.headers));
    _body(b, redactBody(options.data));
    b.write('\n  curl: ${_curl(options)}');
    developer.log(b.toString(), name: _name, level: 700);
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final o = response.requestOptions;
    final b = StringBuffer('← ${response.statusCode} ${o.method} ${o.uri}${_elapsed(o)}');
    _headers(b, redactHeaders(response.headers.map));
    _body(b, redactBody(response.data));
    developer.log(b.toString(), name: _name, level: 800);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final o = err.requestOptions;
    final res = err.response;
    final b = StringBuffer('✗ ${res?.statusCode ?? err.type.name} ${o.method} ${o.uri}${_elapsed(o)}');
    if (res != null) {
      _headers(b, redactHeaders(res.headers.map));
      _body(b, redactBody(res.data));
    }
    developer.log(b.toString(), name: _name, level: 1000, error: err.message);
    handler.next(err);
  }

  /// Appends headers (string or `List<String>` values) as given — callers pass
  /// them through [redactHeaders] first.
  void _headers(StringBuffer b, Map<String, dynamic> headers) {
    if (headers.isEmpty) return;
    b.write('\n  headers:');
    headers.forEach((k, v) => b.write('\n    $k: ${v is List ? v.join(', ') : v}'));
  }

  /// Appends the body, pretty-printed for maps/lists, indented under the log
  /// line. Callers pass it through [redactBody] first.
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

  /// Builds a copy-pasteable `curl` equivalent of [options]. Credentials are
  /// redacted here too — this is the line most likely to be pasted somewhere,
  /// and a runnable command carrying a live bearer token is exactly the
  /// accident worth preventing. Replace the placeholders to run it.
  String _curl(RequestOptions options) {
    final b = StringBuffer('curl -X ${options.method} ${_shQuote(options.uri.toString())}');
    redactHeaders(options.headers).forEach((k, v) {
      final value = v is List ? v.join(', ') : v.toString();
      b.write(' \\\n    -H ${_shQuote('$k: $value')}');
    });
    final data = redactBody(options.data);
    if (data != null) {
      String body;
      if (data is Map || data is List) {
        try {
          body = jsonEncode(data);
        } catch (_) {
          body = data.toString();
        }
      } else {
        body = data.toString();
      }
      if (body.isNotEmpty) b.write(' \\\n    -d ${_shQuote(body)}');
    }
    return b.toString();
  }

  /// Single-quotes a shell argument, escaping embedded single quotes
  /// (`'` → `'\''`) so the printed command is directly runnable.
  String _shQuote(String s) => "'${s.replaceAll("'", "'\\''")}'";
}
