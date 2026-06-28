import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_exception.dart';

/// ({String accessToken, String refreshToken, String userId, bool isNewUser})
typedef AuthTokens = ({
  String accessToken,
  String refreshToken,
  String userId,
  bool isNewUser,
});

/// ({String accessToken, String refreshToken})
typedef RefreshedTokens = ({
  String accessToken,
  String refreshToken,
});

/// Infrastructure adapter — translates .NET REST API calls into typed results.
/// PHI constraint: do not log email, userId, or tokens at any level.
class BalsmAuthAdapter {
  const BalsmAuthAdapter({required Dio dio}) : _dio = dio;

  final Dio _dio;

  // ── OTP flow ─────────────────────────────────────────────────────────────

  /// POST /auth/otp/request
  /// Triggers a one-time-password email to [email].
  Future<void> requestOtp(String email, String countryCode) async {
    await _post('/auth/otp/request', {
      'email': email,
      'country_code': countryCode,
      // captcha_token is added by the interceptor / caller if needed
    });
  }

  /// POST /auth/otp/verify
  /// Returns tokens on success. Throws [AuthException] with code 'account_locked'
  /// and a `Retry-After` header value baked into [AuthException.message] on 423.
  Future<AuthTokens> verifyOtp(
    String email,
    String code,
    String deviceId,
    String deviceLabel,
  ) async {
    final data = await _post('/auth/otp/verify', {
      'email': email,
      'code': code,
      'device_id': deviceId,
      'device_label': deviceLabel,
    });
    return _parseAuthTokens(data);
  }

  // ── Social flows ──────────────────────────────────────────────────────────

  /// POST /auth/google
  Future<AuthTokens> signInWithGoogle(
    String idToken,
    String deviceId,
    String deviceLabel,
  ) async {
    final data = await _post('/auth/google', {
      'id_token': idToken,
      'device_id': deviceId,
      'device_label': deviceLabel,
    });
    return _parseAuthTokens(data);
  }

  /// POST /auth/apple
  Future<AuthTokens> signInWithApple(
    String idToken,
    String authCode,
    String deviceId,
    String deviceLabel,
  ) async {
    final data = await _post('/auth/apple', {
      'id_token': idToken,
      'authorization_code': authCode,
      'device_id': deviceId,
      'device_label': deviceLabel,
    });
    return _parseAuthTokens(data);
  }

  // ── Session management ────────────────────────────────────────────────────

  /// POST /auth/sign-out
  Future<void> signOut() async {
    await _post('/auth/sign-out', {});
  }

  /// POST /auth/refresh
  /// Returns new access + refresh tokens.
  Future<RefreshedTokens> refresh(String refreshToken, String deviceId) async {
    final data = await _post('/auth/refresh', {
      'refresh_token': refreshToken,
      'device_id': deviceId,
    });
    return (
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
    );
  }

  // ── Recovery ──────────────────────────────────────────────────────────────

  /// POST /auth/recovery/claim
  Future<RefreshedTokens> recoveryClaim(
    String recoveryToken,
    String newEmail,
    String deviceId,
    String deviceLabel,
  ) async {
    final data = await _post('/auth/recovery/claim', {
      'recovery_token': recoveryToken,
      'new_email': newEmail,
      'device_id': deviceId,
      'device_label': deviceLabel,
    });
    return (
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
    );
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        data: body,
      );
      return response.data ?? {};
    } on DioException catch (e) {
      _throwTyped(e);
    }
  }

  Never _throwTyped(DioException e) {
    final status = e.response?.statusCode;
    final responseData = e.response?.data;

    // Extract code + message from API error envelope if available.
    String code = 'unknown';
    String message = 'An unexpected error occurred. Please try again.';

    if (responseData is Map<String, dynamic>) {
      code = (responseData['code'] as String?) ?? _codeFromStatus(status);
      // Use generic message; do not echo back server message that may contain PII.
      message = _messageFromCode(code);
    } else {
      code = _codeFromStatus(status);
      message = _messageFromCode(code);
    }

    // Append Retry-After seconds to message for lockout case.
    if (status == 423) {
      final retryAfter = e.response?.headers.value('Retry-After') ?? '60';
      throw AuthException(
        code: 'account_locked',
        message: 'Account temporarily locked. Try again in $retryAfter seconds.',
      );
    }

    throw AuthException(code: code, message: message);
  }

  String _codeFromStatus(int? status) => switch (status) {
        null => 'network_error',
        400 => 'invalid_request',
        401 => 'unauthorized',
        403 => 'forbidden',
        404 => 'not_found',
        409 => 'conflict',
        422 => 'validation_error',
        423 => 'account_locked',
        429 => 'rate_limited',
        >= 500 => 'server_error',
        _ => 'network_error',
      };

  String _messageFromCode(String code) => switch (code) {
        'invalid_request' => 'The request was invalid. Please check your input.',
        'unauthorized' => 'Authentication required. Please sign in again.',
        'forbidden' => 'Access denied.',
        'not_found' => 'The requested resource was not found.',
        'conflict' => 'A conflict occurred. This account may already exist.',
        'validation_error' => 'Validation failed. Please check your input.',
        'account_locked' => 'Account temporarily locked. Please try again later.',
        'rate_limited' => 'Too many requests. Please wait before trying again.',
        'server_error' => 'A server error occurred. Please try again later.',
        'otp_expired' => 'The verification code has expired. Please request a new one.',
        'otp_invalid' => 'Incorrect verification code.',
        _ => 'An unexpected error occurred. Please try again.',
      };

  AuthTokens _parseAuthTokens(Map<String, dynamic> data) => (
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
        userId: data['user_id'] as String,
        isNewUser: (data['is_new_user'] as bool?) ?? false,
      );
}

// ── Riverpod provider ────────────────────────────────────────────────────────

final balsmAuthAdapterProvider = Provider<BalsmAuthAdapter>((ref) {
  final dio = ref.watch(dioClientProvider);
  return BalsmAuthAdapter(dio: dio);
});
