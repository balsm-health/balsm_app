import 'package:balsm_api/balsm_api.dart' show OtpPurpose;
import 'package:core/core.dart';

import '../../domain/aggregates/auth_session.dart';
import '../../domain/events/lockout_triggered.dart';
import '../../domain/events/user_signed_in.dart';
import '../../infrastructure/api/auth_exception.dart';
import '../../infrastructure/api/balsm_auth_adapter.dart';

const _kAccessToken = 'balsm.access_token';
const _kRefreshToken = 'balsm.refresh_token';
const _kUserId = 'balsm.user_id';
const _kDeviceId = 'balsm.device_id';

/// Result of a sign-in attempt; carries the session on lockout for UI display.
sealed class SignInResult {
  const SignInResult();
}

class SignInSuccess extends SignInResult {
  const SignInSuccess({this.isNewUser = false});

  /// True when this sign-in created the account (first OTP verify / social
  /// sign-up). The UI routes new users to profile setup (where the age gate
  /// runs); returning users skip it.
  final bool isNewUser;
}

class SignInLockout extends SignInResult {
  const SignInLockout({required this.session});
  final LockedOut session;
}

/// Handles sign-in for all providers (email OTP, Google, Apple).
///
/// Differences from [SignUpUseCase]:
/// - Dispatches [UserSignedIn] (not [UserSignedUp]).
/// - Handles 423 AccountLocked → [LockoutTriggered] event + [SignInLockout] result.
///
/// PHI constraint: never log email or userId; use correlation IDs only.
class SignInUseCase {
  const SignInUseCase({
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

  /// Step 1 of forgot-password: request a reset code for an existing user.
  /// Email-OTP login was removed, so this is reset-only; the code is submitted
  /// to `resetPassword`. An unknown email returns success with no email sent.
  Future<AppResult<void>> requestEmailOtp(String email, String countryCode) async {
    try {
      await _adapter.requestOtp(email, countryCode, purpose: OtpPurpose.reset);
      return AppResult.success(null);
    } on AuthException catch (e) {
      return AppResult.failure(NetworkFailure(e.message));
    } catch (_) {
      return AppResult.failure(const NetworkFailure());
    }
  }

  /// Step 2: Verify OTP. On 423 returns [AppResult.failure] with a lockout-specific
  /// [NetworkFailure] and fires [LockoutTriggered] on the event bus.
  Future<AppResult<SignInResult>> verifyEmailOtp({
    required String email,
    required String code,
  }) async {
    try {
      final deviceId = await _ensureDeviceId();
      final deviceLabel = _deviceLabel();

      final tokens = await _adapter.verifyOtp(email, code, deviceId, deviceLabel);

      await _persistTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        userId: tokens.userId,
      );

      _bus.publish(UserSignedIn(
        userId: UserId.value(tokens.userId),
        email: email,
        provider: 'email',
      ));

      return AppResult.success(SignInSuccess(isNewUser: tokens.isNewUser));
    } on AuthException catch (e) {
      if (e.code == 'account_locked') {
        return _handleLockout(e, email);
      }
      return AppResult.failure(NetworkFailure(e.message));
    } catch (_) {
      return AppResult.failure(const NetworkFailure());
    }
  }

  /// Magic-link sign-in: redeem the single-use token from the `balsm://auth/link`
  /// deep link for a session. Same persistence + [UserSignedIn] as OTP verify;
  /// the email is unknown here (the token alone identifies the account).
  Future<AppResult<SignInResult>> verifyMagicLink({required String token}) async {
    try {
      final deviceId = await _ensureDeviceId();
      final deviceLabel = _deviceLabel();

      final tokens = await _adapter.verifyLink(token, deviceId, deviceLabel);

      await _persistTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        userId: tokens.userId,
      );

      _bus.publish(UserSignedIn(
        userId: UserId.value(tokens.userId),
        email: '',
        provider: 'email_link',
      ));

      return AppResult.success(SignInSuccess(isNewUser: tokens.isNewUser));
    } on AuthException catch (e) {
      return AppResult.failure(NetworkFailure(e.message));
    } catch (_) {
      return AppResult.failure(const NetworkFailure());
    }
  }

  // ── Email + password ──────────────────────────────────────────────────────

  /// Sign in with email + password. A `401` surfaces as a generic failure (no
  /// account-enumeration); `423` fires [LockoutTriggered] + [SignInLockout].
  Future<AppResult<SignInResult>> passwordSignIn({
    required String email,
    required String password,
  }) async {
    try {
      final deviceId = await _ensureDeviceId();
      final deviceLabel = _deviceLabel();

      final tokens = await _adapter.passwordSignIn(email, password, deviceId, deviceLabel);

      await _persistTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        userId: tokens.userId,
      );

      _bus.publish(UserSignedIn(
        userId: UserId.value(tokens.userId),
        email: email,
        provider: 'email',
      ));

      return AppResult.success(SignInSuccess(isNewUser: tokens.isNewUser));
    } on AuthException catch (e) {
      if (e.code == 'account_locked') return _handleLockout(e, email);
      return AppResult.failure(NetworkFailure(e.message));
    } catch (_) {
      return AppResult.failure(const NetworkFailure());
    }
  }

  /// Reset a forgotten password. Send the code first via [requestEmailOtp]
  /// (forgot-password reuses the OTP-request endpoint).
  Future<AppResult<void>> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      await _adapter.resetPassword(email, code, newPassword);
      return AppResult.success(null);
    } on AuthException catch (e) {
      return AppResult.failure(NetworkFailure(e.message));
    } catch (_) {
      return AppResult.failure(const NetworkFailure());
    }
  }

  /// Set the account password once a session exists — e.g. right after OTP
  /// verify on the password sign-up path. Authenticated request (the bearer is
  /// attached by the auth interceptor).
  Future<AppResult<void>> setPassword({required String password}) async {
    try {
      await _adapter.setPassword(password);
      return AppResult.success(null);
    } on AuthException catch (e) {
      return AppResult.failure(NetworkFailure(e.message));
    } catch (_) {
      return AppResult.failure(const NetworkFailure());
    }
  }

  // ── Google ────────────────────────────────────────────────────────────────

  Future<AppResult<SignInResult>> signInWithGoogle({
    required String idToken,
    required String email,
  }) async {
    try {
      final deviceId = await _ensureDeviceId();
      final deviceLabel = _deviceLabel();

      final tokens = await _adapter.signInWithGoogle(idToken, deviceId, deviceLabel);

      await _persistTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        userId: tokens.userId,
      );

      _bus.publish(UserSignedIn(
        userId: UserId.value(tokens.userId),
        email: email,
        provider: 'google',
      ));

      return AppResult.success(SignInSuccess(isNewUser: tokens.isNewUser));
    } on AuthException catch (e) {
      if (e.code == 'account_locked') return _handleLockout(e, email);
      return AppResult.failure(NetworkFailure(e.message));
    } catch (_) {
      return AppResult.failure(const NetworkFailure());
    }
  }

  // ── Apple ─────────────────────────────────────────────────────────────────

  Future<AppResult<SignInResult>> signInWithApple({
    required String idToken,
    required String authCode,
    required String email,
  }) async {
    try {
      final deviceId = await _ensureDeviceId();
      final deviceLabel = _deviceLabel();

      final tokens = await _adapter.signInWithApple(idToken, authCode, deviceId, deviceLabel);

      await _persistTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        userId: tokens.userId,
      );

      _bus.publish(UserSignedIn(
        userId: UserId.value(tokens.userId),
        email: email,
        provider: 'apple',
      ));

      return AppResult.success(SignInSuccess(isNewUser: tokens.isNewUser));
    } on AuthException catch (e) {
      if (e.code == 'account_locked') return _handleLockout(e, email);
      return AppResult.failure(NetworkFailure(e.message));
    } catch (_) {
      return AppResult.failure(const NetworkFailure());
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  AppResult<SignInResult> _handleLockout(AuthException e, String email) {
    // Parse seconds from message: "...in X seconds."
    final secondsMatch = RegExp(r'in (\d+) seconds').firstMatch(e.message);
    final seconds = int.tryParse(secondsMatch?.group(1) ?? '') ?? 60;
    final until = DateTime.now().toUtc().add(Duration(seconds: seconds));

    // Use a hashed/opaque identifier — do not expose raw email.
    final opaqueId = '${email.hashCode.toRadixString(16)}';

    _bus.publish(LockoutTriggered(identifier: opaqueId, lockedUntil: until));

    return AppResult.success(
      SignInLockout(session: LockedOut(until: until, identifier: opaqueId)),
    );
  }

  Future<String> _ensureDeviceId() async {
    final existing = await _storage.readToken(_kDeviceId);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = UuidV7.generate().toString();
    await _storage.writeToken(_kDeviceId, id);
    return id;
  }

  String _deviceLabel() => 'Balsm Flutter App';

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
