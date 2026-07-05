import 'package:core/core.dart';

import '../../infrastructure/api/auth_exception.dart';
import '../../infrastructure/api/balsm_auth_adapter.dart';

/// Claims a support-issued recovery token via the .NET API
/// (`POST /auth/recovery/claim`). Per Q5 FR-046c/d/e.
///
/// On success the returned tokens are persisted by the caller/adapter; this
/// use case surfaces only success/failure to the presentation layer.
class RecoveryClaimUseCase {
  const RecoveryClaimUseCase({required BalsmAuthAdapter adapter})
      : _adapter = adapter;

  final BalsmAuthAdapter _adapter;

  Future<AppResult<void>> call({
    required String recoveryToken,
    required String newEmail,
    required String deviceId,
    required String deviceLabel,
  }) async {
    try {
      await _adapter.recoveryClaim(
        recoveryToken,
        newEmail,
        deviceId,
        deviceLabel,
      );
      return AppResult.success(null);
    } on AuthException catch (e) {
      return AppResult.failure(NetworkFailure(e.message));
    } catch (_) {
      return AppResult.failure(const NetworkFailure());
    }
  }
}
