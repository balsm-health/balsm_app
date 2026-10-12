import 'dart:convert';

import 'package:core/core.dart';

import '../../domain/events/user_signed_in.dart';
import '../../infrastructure/api/auth_exception.dart';
import '../../infrastructure/api/balsm_auth_adapter.dart';

// Same secure-storage keys as [SignInUseCase] — the recovered session must be
// indistinguishable from a normal sign-in so [SecureStorageAuthRepository] and
// the app-shell `currentUserId` listener treat it identically.
const _kAccessToken = 'balsm.access_token';
const _kRefreshToken = 'balsm.refresh_token';
const _kUserId = 'balsm.user_id';

/// Claims a support-issued recovery token via the .NET API
/// (`POST /auth/recovery/claim`). Per Q5 FR-046c/d/e.
///
/// On success this establishes a live session exactly like the sign-in path:
/// it persists the access/refresh tokens + user id under the same secure-storage
/// keys and publishes [UserSignedIn], so both the session repository and the
/// app-shell in-session user id update without an app restart.
///
/// Note on the user id: `POST /auth/recovery/claim` returns only
/// `{access_token, refresh_token}` (see dotnet-api-endpoints.md and
/// [RefreshedTokens]) — unlike the sign-in endpoints it does NOT echo `user_id`
/// in the body. The user id is therefore read from the `sub` claim of the
/// server-issued access-token JWT (`JwtService.IssueAccessToken(userId, …)`).
/// This is only a source for the local session identity; token security is
/// unchanged — every subsequent request still presents the token for full
/// server-side validation.
class RecoveryClaimUseCase {
  const RecoveryClaimUseCase({
    required BalsmAuthAdapter adapter,
    required SecureStorageWrapper storage,
    required EventBus eventBus,
  })  : _adapter = adapter,
        _storage = storage,
        _bus = eventBus;

  final BalsmAuthAdapter _adapter;
  final SecureStorageWrapper _storage;
  final EventBus _bus;

  Future<AppResult<void>> call({
    required String recoveryToken,
    required String newEmail,
    required String deviceId,
    required String deviceLabel,
  }) async {
    try {
      final tokens = await _adapter.recoveryClaim(
        recoveryToken,
        newEmail,
        deviceId,
        deviceLabel,
      );

      final userId = _userIdFromAccessToken(tokens.accessToken);
      if (userId == null) {
        // Fail closed: never persist a half-established (userId-less) session —
        // it would read back as Unauthenticated anyway (all three keys required).
        return AppResult.failure(const NetworkFailure());
      }

      await _persistTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        userId: userId,
      );

      _bus.publish(UserSignedIn(
        userId: UserId.value(userId),
        email: newEmail,
        provider: 'recovery',
      ));

      return AppResult.success(null);
    } on AuthException catch (e) {
      return AppResult.failure(NetworkFailure(e.message));
    } catch (_) {
      return AppResult.failure(const NetworkFailure());
    }
  }

  // Mirrors SignInUseCase._persistTokens (faithful inline duplication — sharing
  // would require exposing SignInUseCase internals, which is out of scope).
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

  /// Reads the user id from the access-token JWT payload. Prefers the standard
  /// `sub` claim (.NET `JwtRegisteredClaimNames.Sub`), with defensive fallbacks
  /// for other common .NET user-id claim names. Returns null on any malformed
  /// input so the caller can fail closed. Does not verify the signature — the
  /// token was just issued by the server over TLS and is validated server-side
  /// on every subsequent request.
  String? _userIdFromAccessToken(String accessToken) {
    try {
      final parts = accessToken.split('.');
      if (parts.length != 3) return null;
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final claims = json.decode(payload);
      if (claims is! Map) return null;
      for (final key in const [
        'sub',
        'user_id',
        'uid',
        'nameid',
        'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier',
      ]) {
        final v = claims[key];
        if (v is String && v.isNotEmpty) return v;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
