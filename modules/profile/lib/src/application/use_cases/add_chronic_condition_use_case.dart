import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/aggregates/health_profile.dart';
import '../../domain/value_objects/ids.dart';
import '../../domain/events/health_profile_updated.dart';
import '../../infrastructure/drift/profile_dao.dart';

/// Adds a [ChronicCondition] to the user's [HealthProfile] and publishes
/// [HealthProfileUpdated] on the [EventBus].
///
/// PHI is written to the on-device SQLite/SQLCipher store only — no network
/// call, no PHI in logs.
class AddChronicConditionUseCase {
  const AddChronicConditionUseCase({
    required ProfileDao dao,
    required EventBus eventBus,
  })  : _dao = dao,
        _bus = eventBus;

  final ProfileDao _dao;
  final EventBus _bus;

  /// Validates input, persists the condition, and emits an event.
  ///
  /// G7: [icd10Code] and [onsetYear] are optional. When present they are
  /// persisted alongside the condition name (on-device PHI only).
  Future<AppResult<HealthProfile>> execute({
    required UserId userId,
    required String name,
    String? icd10Code,
    int? onsetYear,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return AppResult.failure(
        const ValidationFailure('Condition name is required'),
      );
    }
    if (trimmedName.length > 100) {
      return AppResult.failure(
        const ValidationFailure(
          'Condition name must be 100 characters or fewer',
        ),
      );
    }

    // G7: normalize + validate the optional ICD-10 code / onset year.
    final trimmedIcd10 = icd10Code?.trim();
    final normalizedIcd10 =
        (trimmedIcd10 == null || trimmedIcd10.isEmpty) ? null : trimmedIcd10;
    if (normalizedIcd10 != null && normalizedIcd10.length > 10) {
      return AppResult.failure(
        const ValidationFailure('ICD-10 code must be 10 characters or fewer'),
      );
    }
    if (onsetYear != null) {
      final currentYear = DateTime.now().year;
      if (onsetYear < 1900 || onsetYear > currentYear) {
        return AppResult.failure(
          ValidationFailure('Onset year must be between 1900 and $currentYear'),
        );
      }
    }

    try {
      var profile = await _dao.getProfile(userId);

      if (profile == null) {
        profile = HealthProfile(
          id: HealthProfileId.uuid(),
          userId: userId,
          bloodType: null,
          allergies: const [],
          conditions: const [],
          emergencyContacts: const [],
          updatedAt: DateTime.now().toUtc(),
        );
        await _dao.upsertProfile(profile);
      }

      await _dao.addCondition(
        profile.id,
        ChronicCondition(
          id: ChronicConditionId.uuid(),
          healthProfileId: profile.id,
          name: trimmedName,
          icd10Code: normalizedIcd10,
          onsetYear: onsetYear,
          createdAt: DateTime.now().toUtc(),
        ),
      );

      _bus.publish(
        HealthProfileUpdated(userId: userId, fieldChanged: 'condition_added'),
      );

      final updated = await _dao.getProfile(userId);
      return AppResult.success(updated ?? profile);
    } catch (e) {
      return AppResult.failure(StorageFailure(e.toString()));
    }
  }
}

final addChronicConditionUseCaseProvider =
    Provider<AddChronicConditionUseCase>((ref) {
  return AddChronicConditionUseCase(
    dao: ref.watch(profileDaoProvider),
    eventBus: ref.watch(eventBusProvider),
  );
});
