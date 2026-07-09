import 'package:core/core.dart';

import '../../domain/events/user_signed_up.dart';
import '../../infrastructure/api/balsm_auth_adapter.dart';
import '../../infrastructure/api/auth_exception.dart';

const _kAccessToken = 'balsm.access_token';
const _kRefreshToken = 'balsm.refresh_token';
const _kUserId = 'balsm.user_id';
const _kDeviceId = 'balsm.device_id';

/// Handles new-user sign-up for all providers.
///
/// - Email provider: requests an OTP (caller then navigates to OTP screen).
/// - Google/Apple: completes sign-up in one step, persists tokens, emits event.
///
/// PHI constraint: never log email or userId; use correlation IDs only.
class SignUpUseCase {
  const SignUpUseCase({
    required BalsmAuthAdapter adapter,
    required SecureStorageWrapper storage,
    required EventBus eventBus,
  })  : _adapter = adapter,
        _storage = storage,
        _bus = eventBus;

  final BalsmAuthAdapter _adapter;
  final SecureStorageWrapper _storage;
  final EventBus _bus;

  // ── Email OTP flow ────────────────────────────────────────────────────────

  /// Step 1 of email sign-up: request OTP.
  /// Returns [AppResult.success(null)] on success so the UI can navigate to
  /// the OTP verification screen.
  Future<AppResult<void>> requestEmailOtp(
    String email,
    String countryCode,
  ) async {
    try {
      await _adapter.requestOtp(email, countryCode);
      return AppResult.success(null);
    } on AuthException catch (e) {
      return AppResult.failure(NetworkFailure(e.message));
    } catch (e) {
      return AppResult.failure(const NetworkFailure());
    }
  }

  /// Step 2 of email sign-up: verify OTP and complete sign-up.
  /// Persists tokens and dispatches [UserSignedUp].
  Future<AppResult<void>> verifyEmailOtp({
    required String email,
    required String code,
    required String countryCode,
  }) async {
    try {
      final deviceId = await _ensureDeviceId();
      final deviceLabel = await _deviceLabel();

      final tokens = await _adapter.verifyOtp(email, code, deviceId, deviceLabel);

      await _persistTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        userId: tokens.userId,
      );

      _bus.publish(UserSignedUp(
        userId: UserId.value(tokens.userId),
        email: email,
        provider: 'email',
        countryCode: countryCode,
      ));

      return AppResult.success(null);
    } on AuthException catch (e) {
      return AppResult.failure(NetworkFailure(e.message));
    } catch (e) {
      return AppResult.failure(const NetworkFailure());
    }
  }

  // ── Google sign-up ────────────────────────────────────────────────────────

  /// Complete sign-up via Google.
  /// [idToken] comes from the google_sign_in package.
  Future<AppResult<void>> signUpWithGoogle({
    required String idToken,
    required String countryCode,
    required String email,
  }) async {
    try {
      final deviceId = await _ensureDeviceId();
      final deviceLabel = await _deviceLabel();

      final tokens = await _adapter.signInWithGoogle(idToken, deviceId, deviceLabel);

      await _persistTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        userId: tokens.userId,
      );

      _bus.publish(UserSignedUp(
        userId: UserId.value(tokens.userId),
        email: email,
        provider: 'google',
        countryCode: countryCode,
      ));

      return AppResult.success(null);
    } on AuthException catch (e) {
      return AppResult.failure(NetworkFailure(e.message));
    } catch (e) {
      return AppResult.failure(const NetworkFailure());
    }
  }

  // ── Apple sign-up ─────────────────────────────────────────────────────────

  /// Complete sign-up via Apple.
  /// [idToken] and [authCode] come from the sign_in_with_apple package.
  Future<AppResult<void>> signUpWithApple({
    required String idToken,
    required String authCode,
    required String countryCode,
    required String email,
  }) async {
    try {
      final deviceId = await _ensureDeviceId();
      final deviceLabel = await _deviceLabel();

      final tokens = await _adapter.signInWithApple(idToken, authCode, deviceId, deviceLabel);

      await _persistTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        userId: tokens.userId,
      );

      _bus.publish(UserSignedUp(
        userId: UserId.value(tokens.userId),
        email: email,
        provider: 'apple',
        countryCode: countryCode,
      ));

      return AppResult.success(null);
    } on AuthException catch (e) {
      return AppResult.failure(NetworkFailure(e.message));
    } catch (e) {
      return AppResult.failure(const NetworkFailure());
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<String> _ensureDeviceId() async {
    final existing = await _storage.readToken(_kDeviceId);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = UuidV7.generate().toString();
    await _storage.writeToken(_kDeviceId, id);
    return id;
  }

  Future<String> _deviceLabel() async {
    // Use a fixed label; platform info can be added later without PHI.
    return 'Balsm Flutter App';
  }

  Future<void> _persistTokens({
    required String accessToken,
    required String refreshToken,
    required String userId,
  }) async {
    await Future.wait([
      _storage.writeToken(_kAccessToken, accessToken),
      _storage.writeToken(_kRefreshToken, refreshToken),
      _storage.writeToken(_kUserId, userId),
    ]);
  }
}
