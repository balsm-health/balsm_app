import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';

/// Maps a family-links transport error to the failure the screens branch on.
/// The server's message is never carried: it may echo input.
AppFailure linkFailure(ApiException e) {
  if (e.isOffline) return const OfflineFailure();
  if (e.isUnauthorized) return const UnauthorizedFailure();
  return switch (e.statusCode) {
    404 => const NotFoundFailure('family_link_not_found'),
    409 => const ConflictFailure('family_link_conflict'),
    413 || 422 => const ValidationFailure('family_link_invalid'),
    429 => const NetworkFailure('family_link_rate_limited'),
    _ => const NetworkFailure(),
  };
}
