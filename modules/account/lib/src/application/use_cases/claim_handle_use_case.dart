import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Allowed handle format: 3-30 chars, lowercase letters, digits, `_` and `.`.
final RegExp kHandleFormat = RegExp(r'^[a-z0-9_.]{3,30}$');

/// Validates and claims a public handle for the signed-in user.
///
/// POST /account/handle/claim  body: { "handle": "<value>" }
/// 409 -> [ConflictFailure] ("Handle taken").
class ClaimHandleUseCase {
  ClaimHandleUseCase(this._api);

  final AccountApi _api;

  Future<AppResult<String>> execute(String handle) async {
    final value = handle.trim();
    if (!kHandleFormat.hasMatch(value)) {
      return AppResult.failure(
        const ValidationFailure(
          'Handle must be 3-30 characters using a-z, 0-9, _ or .',
        ),
      );
    }

    try {
      final res = await _api.claimHandle(ClaimHandleRequest(handle: value));
      return AppResult.success(res.handle ?? value);
    } on ApiException catch (e) {
      return AppResult.failure(switch (e.statusCode) {
        409 => const ConflictFailure('Handle taken'),
        401 || 403 => const UnauthorizedFailure(),
        400 || 422 => const ValidationFailure('Invalid handle'),
        _ => const NetworkFailure(),
      });
    }
  }
}

final claimHandleUseCaseProvider = Provider<ClaimHandleUseCase>((ref) {
  return ClaimHandleUseCase(ref.watch(accountApiProvider));
});
