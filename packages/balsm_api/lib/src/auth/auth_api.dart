import 'requests.dart';
import 'responses.dart';

/// Auth endpoints (.NET module: Auth). Flat response bodies.
/// All methods throw [ApiException] on transport errors.
/// PHI constraint: implementations must never log emails, ids, or tokens.
abstract class AuthApi {
  /// POST /auth/otp/request
  Future<void> requestOtp(RequestOtpRequest request);

  /// POST /auth/otp/verify — 423 lockout surfaces code 'account_locked'
  /// with [ApiException.retryAfterSeconds] from the Retry-After header.
  Future<AuthTokensResponse> verifyOtp(VerifyOtpRequest request);

  /// POST /auth/google
  Future<AuthTokensResponse> signInWithGoogle(GoogleSignInRequest request);

  /// POST /auth/apple
  Future<AuthTokensResponse> signInWithApple(AppleSignInRequest request);

  /// POST /auth/sign-out
  Future<void> signOut();

  /// POST /auth/refresh
  Future<RefreshedTokensResponse> refresh(RefreshTokenRequest request);

  /// POST /auth/recovery/claim
  Future<RefreshedTokensResponse> recoveryClaim(RecoveryClaimRequest request);
}
