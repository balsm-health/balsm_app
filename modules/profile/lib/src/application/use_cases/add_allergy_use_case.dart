import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/aggregates/health_profile.dart';
import '../../domain/value_objects/ids.dart';
import '../../domain/events/health_profile_updated.dart';
import '../../infrastructure/drift/profile_data_source.dart';

/// Adds an [Allergy] to the user's [HealthProfile] and publishes
/// [HealthProfileUpdated] on the [EventBus].
///
/// Enforces the max-50-allergies rule (FR). PHI is written to the on-device
/// SQLite/SQLCipher store only — no network call, no PHI in logs.
class AddAllergyUseCase {
  const AddAllergyUseCase({
    required DriftProfileDataSource dao,
    required EventBus eventBus,
  })  : _dao = dao,
        _bus = eventBus;

  final DriftProfileDataSource _dao;
  final EventBus _bus;

  /// Maximum number of allergies a profile may hold.
  static const int maxAllergies = 50;

  /// Validates input, persists the allergy, and emits an event.
  Future<AppResult<HealthProfile>> execute({
    required UserId userId,
    required String name,
    required String severity,
    bool isControlledSubstance = false,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return AppResult.failure(
        const ValidationFailure('Allergy name is required'),
      );
    }
    if (trimmedName.length > 100) {
      return AppResult.failure(
        const ValidationFailure('Allergy name must be 100 characters or fewer'),
      );
    }
    if (!kAllergySeverities.contains(severity)) {
      return AppResult.failure(
        ValidationFailure('Invalid allergy severity: $severity'),
      );
    }

    try {
      var profile = await _dao.getProfile(userId);

      if (profile == null) {
        // First save — create the profile aggregate before adding children.
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

      if (profile.allergies.length >= maxAllergies) {
        return AppResult.failure(
          const ValidationFailure(
            'Cannot add more than $maxAllergies allergies',
          ),
        );
      }

      final allergyId = await _dao.addAllergy(
        profile.id,
        Allergy(
          id: AllergyId.uuid(),
          healthProfileId: profile.id,
          name: trimmedName,
          severity: severity,
          isControlledSubstance: isControlledSubstance,
          createdAt: DateTime.now().toUtc(),
        ),
      );

      _bus.publish(
        HealthProfileUpdated(userId: userId, fieldChanged: 'allergy_added'),
      );

      final updated = await _dao.getProfile(userId);
      // Fall back to a locally-patched aggregate if the re-read fails.
      return AppResult.success(
        updated ??
            profile.copyWith(
              allergies: [
                ...profile.allergies,
                Allergy(
                  id: allergyId,
                  healthProfileId: profile.id,
                  name: trimmedName,
                  severity: severity,
                  isControlledSubstance: isControlledSubstance,
                  createdAt: DateTime.now().toUtc(),
                ),
              ],
            ),
      );
    } catch (e) {
      return AppResult.failure(StorageFailure(e.toString()));
    }
  }
}

final addAllergyUseCaseProvider = Provider<AddAllergyUseCase>((ref) {
  return AddAllergyUseCase(
    dao: ref.watch(profileDataSourceProvider),
    eventBus: ref.watch(eventBusProvider),
  );
});
