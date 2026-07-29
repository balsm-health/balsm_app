import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/aggregates/health_profile.dart';
import '../../domain/events/health_profile_updated.dart';
import '../ports/health_profiles_data_source.dart';
import '../../infrastructure/drift/drift_profile_data_source.dart';

/// Updates the blood_type on an existing [HealthProfile] and publishes
/// [HealthProfileUpdated] on the [EventBus].
///
/// PHI is written to the on-device SQLite/SQLCipher store only — no network call.
class UpdateHealthProfileUseCase {
  const UpdateHealthProfileUseCase({
    required HealthProfilesDataSource dao,
    required EventBus eventBus,
  })  : _dao = dao,
        _bus = eventBus;

  final HealthProfilesDataSource _dao;
  final EventBus _bus;

  /// Creates or updates the profile row and patches [bloodType].
  /// Pass [bloodType] as null to clear the field.
  Future<AppResult<HealthProfile>> execute({
    required UserId userId,
    String? bloodType,
    bool clearBloodType = false,
  }) async {
    if (bloodType != null && !kBloodTypes.contains(bloodType)) {
      return AppResult.failure(
        ValidationFailure('Invalid blood type: $bloodType'),
      );
    }

    try {
      var profile = await _dao.getProfile(userId);

      if (profile == null) {
        // First save — create a new profile aggregate.
        profile = HealthProfile(
          id: HealthProfileId.uuid(),
          userId: userId,
          bloodType: bloodType,
          allergies: const [],
          conditions: const [],
          emergencyContacts: const [],
          updatedAt: DateTime.now().toUtc(),
        );
      } else {
        profile = profile.copyWith(
          bloodType: bloodType,
          clearBloodType: clearBloodType,
          updatedAt: DateTime.now().toUtc(),
        );
      }

      await _dao.upsertProfile(profile);

      _bus.publish(
        HealthProfileUpdated(userId: userId, fieldChanged: 'blood_type'),
      );

      return AppResult.success(profile);
    } catch (e) {
      return AppResult.failure(StorageFailure(e.toString()));
    }
  }
}

final updateHealthProfileUseCaseProvider = Provider<UpdateHealthProfileUseCase>((ref) {
  return UpdateHealthProfileUseCase(
    dao: ref.watch(profileDataSourceProvider),
    eventBus: ref.watch(eventBusProvider),
  );
});
