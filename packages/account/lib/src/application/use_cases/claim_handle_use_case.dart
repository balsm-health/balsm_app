import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Allowed handle format: 3-30 chars, lowercase letters, digits, `_` and `.`.
final RegExp kHandleFormat = RegExp(r'^[a-z0-9_.]{3,30}$');

/// Validates and claims a public handle for the signed-in user.
///
/// POST /account/handle/claim  body: { "handle": "<value>" }
/// 409 -> [ConflictFailure] ("Handle taken").
class ClaimHandleUseCase {
  ClaimHandleUseCase(this._dio);

  final Dio _dio;

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
      final res = await _dio.post<Map<String, dynamic>>(
        '/account/handle/claim',
        data: {'handle': value},
      );
      final data = res.data?['data'] as Map<String, dynamic>?;
      final claimed = (data?['handle'] as String?) ?? value;
      return AppResult.success(claimed);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 409) {
        return AppResult.failure(const ConflictFailure('Handle taken'));
      }
      if (status == 401 || status == 403) {
        return AppResult.failure(const UnauthorizedFailure());
      }
      if (status == 400 || status == 422) {
        return AppResult.failure(const ValidationFailure('Invalid handle'));
      }
      return AppResult.failure(const NetworkFailure());
    }
  }
}

final claimHandleUseCaseProvider = Provider<ClaimHandleUseCase>((ref) {
  return ClaimHandleUseCase(ref.watch(dioClientProvider));
});
