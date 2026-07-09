import 'package:core/core.dart';

import '../../domain/events/user_signed_out.dart';
import '../../infrastructure/api/auth_exception.dart';
import '../../infrastructure/api/balsm_auth_adapter.dart';

const _kAccessToken = 'balsm.access_token';
const _kRefreshToken = 'balsm.refresh_token';
const _kUserId = 'balsm.user_id';

/// Signs the current user out.
///
/// Calls the server endpoint, clears all tokens from [SecureStorageWrapper],
/// and dispatches [UserSignedOut] on the [EventBus].
///
/// If the server call fails (e.g. network error), tokens are still cleared
/// locally so the user is signed out on-device — best-effort server sign-out.
///
/// PHI constraint: never log userId; use correlation IDs only.
class SignOutUseCase {
  const SignOutUseCase({
    required BalsmAuthAdapter adapter,
    required SecureStorageWrapper storage,
    required EventBus eventBus,
  })  : _adapter = adapter,
        _storage = storage,
        _bus = eventBus;

  final BalsmAuthAdapter _adapter;
  final SecureStorageWrapper _storage;
  final EventBus _bus;

  /// Executes sign-out. Always succeeds from the caller's perspective:
  /// even if the server request fails, local tokens are cleared.
  Future<AppResult<void>> call() async {
    // Read userId before clearing so we can publish the event.
    final userId = await _storage.readToken(_kUserId) ?? '';

    // Best-effort server sign-out; ignore errors (token may already be invalid).
    try {
      await _adapter.signOut();
    } on AuthException {
      // Swallow — proceed to local cleanup.
    } catch (_) {
      // Swallow — network may be unavailable.
    }

    // Always clear local tokens.
    try {
      await Future.wait([
        _storage.deleteToken(_kAccessToken),
        _storage.deleteToken(_kRefreshToken),
        _storage.deleteToken(_kUserId),
      ]);
    } on Exception catch (e) {
      return AppResult.failure(StorageFailure(e.toString()));
    }

    _bus.publish(UserSignedOut(userId: UserId.value(userId)));

    return AppResult.success(null);
  }
}
