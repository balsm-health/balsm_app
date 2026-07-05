import 'dart:async';

import 'package:core/core.dart';

import '../../domain/aggregates/auth_session.dart';
import '../../domain/repositories/read_auth_repository.dart';

const _kAccessToken = 'balsm.access_token';
const _kUserId = 'balsm.user_id';
const _kRefreshToken = 'balsm.refresh_token';

/// [ReadAuthRepository] backed by [SecureStorageWrapper].
///
/// The stream emits a new value each time the EventBus fires [UserSignedIn],
/// [UserSignedUp], or [UserSignedOut]. On first subscription it reads the
/// current token state to determine the initial session.
class SecureStorageAuthRepository implements ReadAuthRepository {
  SecureStorageAuthRepository({
    required SecureStorageWrapper storage,
    required EventBus eventBus,
  })  : _storage = storage,
        _bus = eventBus;

  final SecureStorageWrapper _storage;
  final EventBus _bus;

  @override
  Stream<AuthSession> watchSession() async* {
    // Emit the current state immediately.
    yield await _readCurrentSession();

    // Re-read and re-emit whenever any auth event fires.
    await for (final _ in _bus.events) {
      yield await _readCurrentSession();
    }
  }

  Future<AuthSession> _readCurrentSession() async {
    final accessToken = await _storage.readToken(_kAccessToken);
    final userId = await _storage.readToken(_kUserId);
    final refreshToken = await _storage.readToken(_kRefreshToken);

    if (accessToken == null || accessToken.isEmpty ||
        userId == null || userId.isEmpty ||
        refreshToken == null || refreshToken.isEmpty) {
      return const Unauthenticated();
    }

    return Authenticated(
      userId: userId,
      // Email is not stored separately; the server may return it in a future
      // /auth/me endpoint. For now use an empty placeholder — the session
      // aggregate is valid without it for routing purposes.
      email: '',
      provider: 'unknown',
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }
}
