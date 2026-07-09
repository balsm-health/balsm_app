import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/value_objects/ids.dart';
import '../../domain/events/session_revoked.dart';

/// Revokes every session via `POST /sessions/revoke-all`.
///
/// On success the server returns `{revoked_count}` and a [SessionRevoked]
/// event is dispatched to signal the global revocation.
class SignOutEverywhereUseCase {
  SignOutEverywhereUseCase(this._api, this._bus);

  final SessionsApi _api;
  final EventBus _bus;

  Future<AppResult<int>> call() async {
    try {
      final res = await _api.revokeAllSessions();

      _bus.publish(
        const SessionRevoked(sessionId: SessionId.value('*'), deviceLabel: 'All devices'),
      );

      return AppResult.success(res.revokedCount);
    } on ApiException catch (e) {
      return AppResult.failure(_failureFor(e));
    }
  }

  AppFailure _failureFor(ApiException e) {
    if (e.fromEnvelope) {
      return ValidationFailure(
          e.serverMessage ?? 'Unable to sign out everywhere.');
    }
    if (e.isUnauthorized) return const UnauthorizedFailure();
    return const NetworkFailure();
  }
}

final signOutEverywhereUseCaseProvider =
    Provider<SignOutEverywhereUseCase>((ref) {
  return SignOutEverywhereUseCase(
    ref.watch(sessionsApiProvider),
    ref.watch(eventBusProvider),
  );
});
