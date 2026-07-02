import 'package:dio/dio.dart' show CancelToken;

import 'requests.dart';
import 'responses.dart';

/// Auth endpoints (.NET module: Auth). Flat response bodies.
/// All methods throw [ApiException] on transport errors.
/// PHI constraint: implementations must never log emails, ids, or tokens.
/// Pass a [CancelToken] to abort the request; a cancelled request throws
/// [ApiException] with `isCancelled == true`.
abstract class AuthApi {
  /// POST /auth/otp/request
  Future<void> requestOtp(RequestOtpRequest request, {CancelToken? cancelToken});

  /// POST /auth/otp/verify — 423 lockout surfaces code 'account_locked'
  /// with [ApiException.retryAfterSeconds] from the Retry-After header.
  Future<AuthTokensResponse> verifyOtp(VerifyOtpRequest request,
      {CancelToken? cancelToken});

  /// POST /auth/google
  Future<AuthTokensResponse> signInWithGoogle(GoogleSignInRequest request,
      {CancelToken? cancelToken});

  /// POST /auth/apple
  Future<AuthTokensResponse> signInWithApple(AppleSignInRequest request,
      {CancelToken? cancelToken});

  /// POST /auth/sign-out
  Future<void> signOut({CancelToken? cancelToken});

  /// POST /auth/refresh
  Future<RefreshedTokensResponse> refresh(RefreshTokenRequest request,
      {CancelToken? cancelToken});

  /// POST /auth/recovery/claim
  Future<RefreshedTokensResponse> recoveryClaim(RecoveryClaimRequest request,
      {CancelToken? cancelToken});
}
