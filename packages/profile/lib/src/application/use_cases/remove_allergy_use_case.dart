import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/aggregates/health_profile.dart';
import '../../domain/events/health_profile_updated.dart';
import '../../infrastructure/drift/profile_dao.dart';

/// Removes an [Allergy] from the user's [HealthProfile] and publishes
/// [HealthProfileUpdated] on the [EventBus].
///
/// PHI is mutated in the on-device SQLite/SQLCipher store only — no network
/// call, no PHI in logs.
class RemoveAllergyUseCase {
  const RemoveAllergyUseCase({
    required ProfileDao dao,
    required EventBus eventBus,
  })  : _dao = dao,
        _bus = eventBus;

  final ProfileDao _dao;
  final EventBus _bus;

  /// Deletes the allergy [allergyId] belonging to [userId] and emits an event.
  Future<AppResult<HealthProfile>> execute({
    required String userId,
    required UuidV7 allergyId,
  }) async {
    try {
      final profile = await _dao.getProfile(userId);
      if (profile == null) {
        return AppResult.failure(
          const NotFoundFailure('Health profile not found'),
        );
      }

      await _dao.removeAllergy(allergyId);

      _bus.publish(
        HealthProfileUpdated(userId: userId, fieldChanged: 'allergy_removed'),
      );

      final updated = await _dao.getProfile(userId);
      return AppResult.success(updated ?? profile);
    } catch (e) {
      return AppResult.failure(StorageFailure(e.toString()));
    }
  }
}

final removeAllergyUseCaseProvider = Provider<RemoveAllergyUseCase>((ref) {
  return RemoveAllergyUseCase(
    dao: ref.watch(profileDaoProvider),
    eventBus: ref.watch(eventBusProvider),
  );
});
