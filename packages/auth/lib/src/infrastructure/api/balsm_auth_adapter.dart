import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart'; // for authApiProvider; core does NOT re-export AuthApi, so no clash
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

/// Anti-corruption adapter — maps balsm_api DTOs/ApiException into the auth
/// module's records and AuthException.
/// PHI constraint: do not log email, userId, or tokens at any level.
class BalsmAuthAdapter {
  const BalsmAuthAdapter({required AuthApi api}) : _api = api;

  final AuthApi _api;

  /// POST /auth/otp/request
  Future<void> requestOtp(String email, String countryCode,
          {CancelToken? cancelToken}) =>
      _guard(() => _api.requestOtp(
            RequestOtpRequest(email: email, countryCode: countryCode),
            cancelToken: cancelToken,
          ));

  /// POST /auth/otp/verify
  Future<AuthTokens> verifyOtp(
    String email,
    String code,
    String deviceId,
    String deviceLabel, {
    CancelToken? cancelToken,
  }) =>
      _guard(() async => _toAuthTokens(await _api.verifyOtp(
            VerifyOtpRequest(
              email: email,
              code: code,
              deviceId: deviceId,
              deviceLabel: deviceLabel,
            ),
            cancelToken: cancelToken,
          )));

  /// POST /auth/google
  Future<AuthTokens> signInWithGoogle(
    String idToken,
    String deviceId,
    String deviceLabel, {
    CancelToken? cancelToken,
  }) =>
      _guard(() async => _toAuthTokens(await _api.signInWithGoogle(
            GoogleSignInRequest(
              idToken: idToken,
              deviceId: deviceId,
              deviceLabel: deviceLabel,
            ),
            cancelToken: cancelToken,
          )));

  /// POST /auth/apple
  Future<AuthTokens> signInWithApple(
    String idToken,
    String authCode,
    String deviceId,
    String deviceLabel, {
    CancelToken? cancelToken,
  }) =>
      _guard(() async => _toAuthTokens(await _api.signInWithApple(
            AppleSignInRequest(
              idToken: idToken,
              authorizationCode: authCode,
              deviceId: deviceId,
              deviceLabel: deviceLabel,
            ),
            cancelToken: cancelToken,
          )));

  /// POST /auth/sign-out
  Future<void> signOut({CancelToken? cancelToken}) =>
      _guard(() => _api.signOut(cancelToken: cancelToken));

  /// POST /auth/refresh
  Future<RefreshedTokens> refresh(String refreshToken, String deviceId,
          {CancelToken? cancelToken}) =>
      _guard(() async {
        final r = await _api.refresh(
          RefreshTokenRequest(refreshToken: refreshToken, deviceId: deviceId),
          cancelToken: cancelToken,
        );
        return (accessToken: r.accessToken, refreshToken: r.refreshToken);
      });

  /// POST /auth/recovery/claim
  Future<RefreshedTokens> recoveryClaim(
    String recoveryToken,
    String newEmail,
    String deviceId,
    String deviceLabel, {
    CancelToken? cancelToken,
  }) =>
      _guard(() async {
        final r = await _api.recoveryClaim(
          RecoveryClaimRequest(
            recoveryToken: recoveryToken,
            newEmail: newEmail,
            deviceId: deviceId,
            deviceLabel: deviceLabel,
          ),
          cancelToken: cancelToken,
        );
        return (accessToken: r.accessToken, refreshToken: r.refreshToken);
      });

  // ── Internals ─────────────────────────────────────────────────────────────

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on ApiException catch (e) {
      throw _toAuthException(e);
    }
  }

  AuthTokens _toAuthTokens(AuthTokensResponse r) => (
        accessToken: r.accessToken,
        refreshToken: r.refreshToken,
        userId: r.userId,
        isNewUser: r.isNewUser,
      );

  AuthException _toAuthException(ApiException e) {
    if (e.statusCode == 423) {
      final retryAfter = e.retryAfterSeconds ?? 60;
      return AuthException(
        code: 'account_locked',
        message: 'Account temporarily locked. Try again in $retryAfter seconds.',
      );
    }
    // Use generic message; never echo server text (may contain PII).
    return AuthException(code: e.code, message: _messageFromCode(e.code));
  }

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
}

// ── Riverpod provider ────────────────────────────────────────────────────────

final balsmAuthAdapterProvider = Provider<BalsmAuthAdapter>((ref) {
  return BalsmAuthAdapter(api: ref.watch(authApiProvider));
});
