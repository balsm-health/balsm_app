import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/events/session_revoked.dart';

/// Revokes a single device session via `DELETE /sessions/{id}`.
///
/// Revocation is one-way; on success a [SessionRevoked] event is dispatched.
class RevokeSessionUseCase {
  RevokeSessionUseCase(this._api, this._bus);

  final SessionsApi _api;
  final EventBus _bus;

  Future<AppResult<void>> call({
    required String sessionId,
    required String deviceLabel,
  }) async {
    try {
      await _api.revokeSession(sessionId);
      _bus.publish(
        SessionRevoked(sessionId: sessionId, deviceLabel: deviceLabel),
      );
      return AppResult.success<void>(null);
    } on ApiException catch (e) {
      return AppResult.failure<void>(_failureFor(e));
    }
  }

  AppFailure _failureFor(ApiException e) {
    if (e.fromEnvelope) {
      return ValidationFailure(e.serverMessage ?? 'Unable to revoke session.');
    }
    if (e.isUnauthorized) return const UnauthorizedFailure();
    if (e.statusCode == 404) return const NotFoundFailure('Session not found.');
    return const NetworkFailure();
  }
}

final revokeSessionUseCaseProvider = Provider<RevokeSessionUseCase>((ref) {
  return RevokeSessionUseCase(
    ref.watch(sessionsApiProvider),
    ref.watch(eventBusProvider),
  );
});
