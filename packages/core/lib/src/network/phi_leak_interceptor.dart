import 'package:dio/dio.dart';

/// PHI-leak guard for the Dio client.
///
/// IMPORTANT: this interceptor MUST NOT mutate the outbound request body.
/// The .NET API is the trusted recipient and legitimately needs PHI-adjacent
/// fields (email, encrypted ciphertext, etc.) over TLS — stripping them would
/// break every endpoint. PHI redaction for crash reporting happens in
/// `sentry_init.dart` (`beforeSend` / `beforeBreadcrumb`).
///
/// What this interceptor does instead: it attaches a *scrubbed copy* of the
/// request/response body under `RequestOptions.extra['phi_safe_body']` so any
/// downstream logger/telemetry can emit a safe representation without ever
/// touching the real payload on the wire.
class PhiLeakInterceptor extends Interceptor {
  /// Non-PHI fields safe to surface in logs/telemetry. Everything else is
  /// redacted to `'[redacted]'` in the telemetry copy (never on the wire).
  static const allowedFields = {
    'event_id', 'timestamp', 'platform', 'level', 'logger',
    'transaction', 'environment', 'release', 'status_code',
    'method', 'url', 'reason', 'type', 'value', 'correlationId',
    'expires_in_seconds', 'ttl_seconds', 'is_new_user', 'deletion_state',
    'token_id', 'expires_at', 'revoked', 'revoked_count',
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.data is Map) {
      // Do NOT mutate options.data — only stash a safe copy for logging.
      options.extra['phi_safe_body'] = scrubForTelemetry(options.data as Map);
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    handler.next(response);
  }

  /// Returns a copy of [data] with any non-allowlisted key's value replaced by
  /// `'[redacted]'`. Use this for log/telemetry output only.
  static Map<String, dynamic> scrubForTelemetry(Map<dynamic, dynamic> data) {
    return {
      for (final e in data.entries)
        e.key.toString(): allowedFields.contains(e.key.toString())
            ? e.value
            : '[redacted]',
    };
  }
}
