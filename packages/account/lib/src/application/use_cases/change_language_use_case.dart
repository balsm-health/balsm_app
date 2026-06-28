import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/events/language_changed.dart';

/// Changes the signed-in user's preferred language (BCP-47 tag).
///
/// POST /account/language  body: { "preferredLanguage": "<bcp47>" }.
/// On success, dispatches [LanguageChanged] so the UI can flip
/// Directionality / reload translations.
class ChangeLanguageUseCase {
  ChangeLanguageUseCase({required Dio dio, required EventBus bus})
      : _dio = dio,
        _bus = bus;

  final Dio _dio;
  final EventBus _bus;

  Future<AppResult<String>> execute({
    required String userId,
    required String oldLanguage,
    required String newLanguage,
  }) async {
    final tag = Bcp47Tag(newLanguage);
    if (!tag.isFirstClass) {
      return AppResult.failure(
        const ValidationFailure('Unsupported language'),
      );
    }

    try {
      await _dio.post<Map<String, dynamic>>(
        '/account/language',
        data: {'preferredLanguage': tag.value},
      );
      _bus.publish(
        LanguageChanged(
          userId: userId,
          oldLanguage: oldLanguage,
          newLanguage: tag.value,
        ),
      );
      return AppResult.success(tag.value);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        return AppResult.failure(const UnauthorizedFailure());
      }
      if (status == 400 || status == 422) {
        return AppResult.failure(const ValidationFailure('Invalid language'));
      }
      return AppResult.failure(const NetworkFailure());
    }
  }
}

final changeLanguageUseCaseProvider = Provider<ChangeLanguageUseCase>((ref) {
  return ChangeLanguageUseCase(
    dio: ref.watch(dioClientProvider),
    bus: ref.watch(eventBusProvider),
  );
});
