import 'dart:convert';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';

/// Debug-only Dio interceptor that logs the FULL request and response —
/// method, URL, every header, and the complete body — to the dev console
/// (`dart:developer.log`, tag `balsm.http`).
///
/// Verbatim by default, including bearer tokens, passwords and one-time codes:
/// the whole point of this log is to see exactly what went over the wire, and
/// a curl line you cannot run is not much use. [redact] replaces credentials
/// for the times a log is going somewhere other than your own terminal — a bug
/// report, a chat, a screen recording. Anything pasted out of an unredacted log
/// has left the device with live credentials in it.
///
/// DEBUG BUILDS ONLY either way — it prints PHI, and it is wired in
/// `BalsmApiController.create` behind `kDebugMode`.
class HttpLogInterceptor extends Interceptor {
  const HttpLogInterceptor({this.redact = false});

  /// Replace credentials with [redacted] instead of printing them. Off by
  /// default; see the class comment for when to turn it on.
  final bool redact;

  static const _name = 'balsm.http';
  static const _encoder = JsonEncoder.withIndent('  ');

  /// Stands in for any value that must not be printed.
  static const redacted = '••• redacted •••';

  /// Body keys whose value is always a credential. Matched case-insensitively
  /// and by containment, so `new_password`, `refreshToken` and `id_token` are
  /// covered without listing every spelling the API uses.
  static const _secretKeyParts = [
    'password',
    'token',
    'secret',
    'authorization',
    'cookie',
  ];

  /// `code` is not one of them. It is the one-time code on the way out and the
  /// FAILURE NAME on the way back — InvalidCredentials, RateLimitExceeded,
  /// AccountLocked — and hiding those leaves a log that says a request failed
  /// and refuses to say how. So a code is judged by its value: four to eight
  /// digits and nothing else is an OTP; anything else is a name, a country, or
  /// a status.
  static final _otpValue = RegExp(r'^\d{4,8}$');

  static bool _isSecretKey(Object? key) {
    final k = key.toString().toLowerCase();
    return _secretKeyParts.any(k.contains);
  }

  static bool _isSecret(Object? key, Object? value) =>
      _isSecretKey(key) || (key.toString().toLowerCase().contains('code') && _looksLikeOtp(value));

  static bool _looksLikeOtp(Object? value) => value is String && _otpValue.hasMatch(value);

  /// [data] with every credential value replaced.
  ///
  /// Maps and lists are walked; anything else is returned untouched rather
  /// than guessed at — a redactor that mangles an unrecognised body makes the
  /// log useless for the case you most need it.
  static Object? redactBody(Object? data) {
    if (data is Map) {
      return {
        for (final entry in data.entries)
          entry.key: _isSecret(entry.key, entry.value) ? redacted : redactBody(entry.value),
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
          entry.key: !_isSecretKey(entry.key)
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
    _headers(b, _headersFor(options.headers));
    _body(b, _bodyFor(options.data));
    b.write('\n  curl: ${_curl(options)}');
    developer.log(b.toString(), name: _name, level: 700);
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final o = response.requestOptions;
    final b = StringBuffer('← ${response.statusCode} ${o.method} ${o.uri}${_elapsed(o)}');
    _headers(b, _headersFor(response.headers.map));
    _body(b, _bodyFor(response.data));
    developer.log(b.toString(), name: _name, level: 800);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final o = err.requestOptions;
    final res = err.response;
    final b = StringBuffer('✗ ${res?.statusCode ?? err.type.name} ${o.method} ${o.uri}${_elapsed(o)}');
    if (res != null) {
      _headers(b, _headersFor(res.headers.map));
      _body(b, _bodyFor(res.data));
    }
    developer.log(b.toString(), name: _name, level: 1000, error: err.message);
    handler.next(err);
  }

  Object? _bodyFor(Object? data) => redact ? redactBody(data) : data;

  Map<String, dynamic> _headersFor(Map<String, dynamic> headers) => redact ? redactHeaders(headers) : headers;

  /// Appends headers (string or `List<String>` values) as given — callers pass
  /// them through [_headersFor] first.
  void _headers(StringBuffer b, Map<String, dynamic> headers) {
    if (headers.isEmpty) return;
    b.write('\n  headers:');
    headers.forEach((k, v) => b.write('\n    $k: ${v is List ? v.join(', ') : v}'));
  }

  /// Appends the body, pretty-printed for maps/lists, indented under the log
  /// line. Callers pass it through [_bodyFor] first.
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

  /// Builds a copy-pasteable `curl` equivalent of [options] — method, every
  /// header, and the body. Runnable as printed unless [redact] is on, in which
  /// case the placeholders have to be filled in by hand.
  String _curl(RequestOptions options) {
    final b = StringBuffer('curl -X ${options.method} ${_shQuote(options.uri.toString())}');
    _headersFor(options.headers).forEach((k, v) {
      final value = v is List ? v.join(', ') : v.toString();
      b.write(' \\\n    -H ${_shQuote('$k: $value')}');
    });
    final data = _bodyFor(options.data);
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
