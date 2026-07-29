import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Changes the signed-in user's preferred language (BCP-47 tag).
///
/// POST /account/language  body: { "preferred_language": "<bcp47>" }.
/// On success, dispatches [LanguageChanged] so the UI can flip
/// Directionality / reload translations.
class ChangeLanguageUseCase {
  ChangeLanguageUseCase({required AccountApi api, required EventBus bus})
      : _api = api,
        _bus = bus;

  final AccountApi _api;
  final EventBus _bus;

  Future<AppResult<String>> execute({
    required UserId userId,
    required String oldLanguage,
    required String newLanguage,
  }) async {
    final tag = LanguageCode.tryParseUi(newLanguage);
    if (tag == null) {
      return AppResult.failure(
        const ValidationFailure('Unsupported language'),
      );
    }

    try {
      await _api.changeLanguage(
        ChangeLanguageRequest(preferredLanguage: tag.value),
      );
      _bus.publish(
        LanguageChanged(
          userId: userId,
          oldLanguage: oldLanguage,
          newLanguage: tag.value,
        ),
      );
      return AppResult.success(tag.value);
    } on ApiException catch (e) {
      return AppResult.failure(switch (e.statusCode) {
        401 || 403 => const UnauthorizedFailure(),
        400 || 422 => const ValidationFailure('Invalid language'),
        _ => const NetworkFailure(),
      });
    }
  }
}

final changeLanguageUseCaseProvider = Provider<ChangeLanguageUseCase>((ref) {
  return ChangeLanguageUseCase(
    api: ref.watch(accountApiProvider),
    bus: ref.watch(eventBusProvider),
  );
});
