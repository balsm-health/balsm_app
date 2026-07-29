import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/aggregates/active_session.dart';
import '../../domain/value_objects/ids.dart';

/// Lists the current user's active device sessions via `GET /sessions`.
class ListActiveSessionsUseCase {
  ListActiveSessionsUseCase(this._api);

  final SessionsApi _api;

  Future<AppResult<List<ActiveSession>>> call() async {
    try {
      final sessions = await _api.listSessions();
      return AppResult.success(
        sessions.map(_toDomain).toList(growable: false),
      );
    } on ApiException catch (e) {
      return AppResult.failure(_failureFor(e));
    }
  }

  ActiveSession _toDomain(SessionResponse r) => ActiveSession(
        id: SessionId.value(r.id),
        deviceId: DeviceId.value(r.deviceId),
        deviceLabel: r.deviceLabel,
        deviceType: r.deviceType,
        firstSeenAt: r.firstSeenAt,
        lastActivityAt: r.lastActivityAt,
        revokedAt: r.revokedAt,
        isCurrent: r.isCurrent,
        approxLocation: r.approxLocation, // G11: null until the API returns it
      );

  AppFailure _failureFor(ApiException e) {
    if (e.fromEnvelope) {
      return ValidationFailure(e.serverMessage ?? 'Unable to load sessions.');
    }
    if (e.isUnauthorized) return const UnauthorizedFailure();
    return const NetworkFailure();
  }
}

final listActiveSessionsUseCaseProvider = Provider<ListActiveSessionsUseCase>((ref) {
  return ListActiveSessionsUseCase(ref.watch(sessionsApiProvider));
});
