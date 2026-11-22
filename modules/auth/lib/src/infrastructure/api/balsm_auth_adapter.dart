import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart'; // for authApiProvider; core does NOT re-export AuthApi, so no clash
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../i18n/strings.dart';
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
  const BalsmAuthAdapter({required AuthApi api, String Function()? language})
      : _api = api,
        _language = language;

  final AuthApi _api;

  /// The app's current language, sent with a code request so the email is
  /// written in it.
  final String Function()? _language;

  /// POST /auth/otp/request
  Future<void> requestOtp(
    String email,
    String countryCode, {
    required OtpPurpose purpose,
    CancelToken? cancelToken,
  }) =>
      _guard(
        () => _api.requestOtp(
          RequestOtpRequest(email: email, countryCode: countryCode, purpose: purpose, language: _language?.call()),
          cancelToken: cancelToken,
        ),
      );

  /// POST /auth/otp/verify
  Future<AuthTokens> verifyOtp(
    String email,
    String code,
    String deviceId,
    String deviceLabel, {
    CancelToken? cancelToken,
  }) =>
      _guard(
        () async => _toAuthTokens(
          await _api.verifyOtp(
            VerifyOtpRequest(
              email: email,
              code: code,
              deviceId: deviceId,
              deviceLabel: deviceLabel,
            ),
            cancelToken: cancelToken,
          ),
        ),
      );

  /// POST /auth/otp/verify for a device-only account going online. Returns
  /// whether the server kept the device's id.
  Future<({AuthTokens tokens, bool adoptedClientId})> verifyOtpClaim(
    String email,
    String code,
    String deviceId,
    String deviceLabel,
    String clientAccountId, {
    CancelToken? cancelToken,
  }) =>
      _guard(() async {
        final r = await _api.verifyOtp(
          VerifyOtpRequest(
            email: email,
            code: code,
            deviceId: deviceId,
            deviceLabel: deviceLabel,
            clientAccountId: clientAccountId,
          ),
          cancelToken: cancelToken,
        );
        return (tokens: _toAuthTokens(r), adoptedClientId: r.adoptedClientId);
      });

  /// POST /auth/otp/verify-link — redeem a magic sign-in link token.
  Future<AuthTokens> verifyLink(
    String token,
    String deviceId,
    String deviceLabel, {
    CancelToken? cancelToken,
  }) =>
      _guard(
        () async => _toAuthTokens(
          await _api.verifyLink(
            VerifyLinkRequest(
              token: token,
              deviceId: deviceId,
              deviceLabel: deviceLabel,
            ),
            cancelToken: cancelToken,
          ),
        ),
      );

  /// POST /auth/google
  Future<AuthTokens> signInWithGoogle(
    String idToken,
    String deviceId,
    String deviceLabel,
    String countryCode, {
    CancelToken? cancelToken,
  }) =>
      _guard(
        () async => _toAuthTokens(
          await _api.signInWithGoogle(
            GoogleSignInRequest(
              idToken: idToken,
              deviceId: deviceId,
              deviceLabel: deviceLabel,
              countryCode: countryCode,
            ),
            cancelToken: cancelToken,
          ),
        ),
      );

  /// POST /auth/apple
  Future<AuthTokens> signInWithApple(
    String idToken,
    String authCode,
    String deviceId,
    String deviceLabel,
    String countryCode, {
    CancelToken? cancelToken,
  }) =>
      _guard(
        () async => _toAuthTokens(
          await _api.signInWithApple(
            AppleSignInRequest(
              idToken: idToken,
              authorizationCode: authCode,
              deviceId: deviceId,
              deviceLabel: deviceLabel,
              countryCode: countryCode,
            ),
            cancelToken: cancelToken,
          ),
        ),
      );

  /// POST /auth/sign-out
  Future<void> signOut({CancelToken? cancelToken}) => _guard(() => _api.signOut(cancelToken: cancelToken));

  /// POST /auth/refresh
  Future<RefreshedTokens> refresh(String refreshToken, String deviceId, {CancelToken? cancelToken}) => _guard(() async {
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

  /// POST /auth/password/sign-in
  Future<AuthTokens> passwordSignIn(
    String email,
    String password,
    String deviceId,
    String deviceLabel, {
    CancelToken? cancelToken,
  }) =>
      _guard(
        () async => _toAuthTokens(
          await _api.passwordSignIn(
            PasswordSignInRequest(
              email: email,
              password: password,
              deviceId: deviceId,
              deviceLabel: deviceLabel,
            ),
            cancelToken: cancelToken,
          ),
        ),
      );

  /// POST /auth/password — set/change the signed-in user's password.
  Future<void> setPassword(String password, {CancelToken? cancelToken}) => _guard(
        () => _api.setPassword(
          SetPasswordRequest(password: password),
          cancelToken: cancelToken,
        ),
      );

  /// POST /auth/password/reset
  Future<void> resetPassword(
    String email,
    String code,
    String newPassword, {
    CancelToken? cancelToken,
  }) =>
      _guard(
        () => _api.resetPassword(
          ResetPasswordRequest(email: email, code: code, newPassword: newPassword),
          cancelToken: cancelToken,
        ),
      );

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
        message: authStrings.current.errorLockedFor(retryAfter),
      );
    }
    // Use generic message; never echo server text (may contain PII).
    return AuthException(code: e.code, message: _messageFromCode(e.code));
  }

  /// The user-facing message for an API error [code], in the active language. Infrastructure reads the
  /// module bundle synchronously (`authStrings.current`), as its docs allow outside presentation.
  String _messageFromCode(String code) {
    final m = authStrings.current;
    return switch (code) {
      'invalid_request' => m.errorInvalidRequest,
      'unauthorized' => m.errorUnauthorized,
      'forbidden' => m.errorForbidden,
      'not_found' => m.errorNotFound,
      'conflict' => m.errorConflict,
      'validation_error' => m.errorValidation,
      'account_locked' => m.errorLocked,
      'rate_limited' => m.errorRateLimited,
      'server_error' => m.errorServer,
      'otp_expired' => m.errorOtpExpired,
      'otp_invalid' => m.errorOtpInvalid,
      _ => m.errorUnexpected,
    };
  }
}

// ── Riverpod provider ────────────────────────────────────────────────────────

final balsmAuthAdapterProvider = Provider<BalsmAuthAdapter>((ref) {
  return BalsmAuthAdapter(api: ref.watch(authApiProvider), language: ref.watch(apiLanguageProvider));
});
