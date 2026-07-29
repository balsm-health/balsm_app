import 'package:dio/dio.dart';

/// Transport-level error thrown by every Dio-backed API implementation.
///
/// PHI constraint: [toString] must never include [serverMessage] or any
/// payload content — server text may echo user input (emails, names).
class ApiException implements Exception {
  const ApiException({
    required this.code,
    this.statusCode,
    this.serverMessage,
    this.retryAfterSeconds,
    this.fromEnvelope = false,
  });

  /// Machine-readable code: server-provided `code` when present, else
  /// derived from the HTTP status via [codeForStatus].
  final String code;

  final int? statusCode;

  /// Raw server-provided message. May contain PII — the display layer
  /// decides whether to show it; never log it.
  final String? serverMessage;

  /// Parsed `Retry-After` header in seconds (lockout/rate-limit responses).
  final int? retryAfterSeconds;

  /// True when the failure came from a `{data, error}` envelope on an
  /// otherwise-successful HTTP response (legacy behavior surfaces these as
  /// validation failures with the server message).
  final bool fromEnvelope;

  bool get isUnauthorized => statusCode == 401 || statusCode == 403;

  /// True when the request was aborted via its [CancelToken].
  bool get isCancelled => code == 'cancelled';

  factory ApiException.fromDioException(DioException e) {
    // A caller-initiated cancellation is not a server error — surface it
    // distinctly so callers can ignore it rather than show a failure.
    if (e.type == DioExceptionType.cancel) {
      return const ApiException(code: 'cancelled');
    }
    final status = e.response?.statusCode;
    final data = e.response?.data;
    String? code;
    String? message;
    if (data is Map<String, dynamic>) {
      code = data['code'] as String?;
      message = data['message'] as String?;
      final error = data['error'];
      if (error is Map<String, dynamic>) {
        code ??= error['code'] as String?;
        message ??= error['message'] as String?;
      }
    }
    final retryAfterRaw = e.response?.headers.value('Retry-After');
    return ApiException(
      code: code ?? codeForStatus(status),
      statusCode: status,
      serverMessage: message,
      retryAfterSeconds: retryAfterRaw == null ? null : int.tryParse(retryAfterRaw),
    );
  }

  factory ApiException.fromEnvelopeError(Object error, {int? statusCode}) {
    if (error is Map<String, dynamic>) {
      return ApiException(
        code: (error['code'] as String?) ?? 'server_error',
        statusCode: statusCode,
        serverMessage: error['message'] as String?,
        fromEnvelope: true,
      );
    }
    return ApiException(
      code: 'server_error',
      statusCode: statusCode,
      fromEnvelope: true,
    );
  }

  /// Status → code mapping, lifted verbatim from the legacy auth adapter
  /// (plus 410 for expired emergency-QR tokens).
  static String codeForStatus(int? status) => switch (status) {
        null => 'network_error',
        400 => 'invalid_request',
        401 => 'unauthorized',
        403 => 'forbidden',
        404 => 'not_found',
        409 => 'conflict',
        410 => 'gone',
        422 => 'validation_error',
        423 => 'account_locked',
        429 => 'rate_limited',
        >= 500 => 'server_error',
        _ => 'network_error',
      };

  @override
  String toString() => 'ApiException(code: $code, status: $statusCode)';
}
