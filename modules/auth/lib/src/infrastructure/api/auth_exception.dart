/// Typed exception for auth-related API errors.
/// PHI constraint: [message] must not contain email, userId, or other PII.
class AuthException implements Exception {
  const AuthException({required this.code, required this.message});

  /// Machine-readable error code (e.g. 'otp_expired', 'account_locked').
  final String code;

  /// Human-readable message safe for display. Must not contain PII.
  final String message;

  @override
  String toString() => 'AuthException($code): $message';
}
