import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/aggregates/health_profile.dart';
import '../../domain/events/health_profile_updated.dart';
import '../ports/health_profiles_data_source.dart';
import '../../infrastructure/drift/drift_profile_data_source.dart';

/// Updates fields on an existing [HealthProfile] and publishes
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

  /// Creates or updates the profile row. Pass [clear*] to wipe a field.
  /// Blood type, weight, and height are independent patches — omitted values
  /// keep the current stored value.
  Future<AppResult<HealthProfile>> execute({
    required UserId userId,
    String? bloodType,
    bool clearBloodType = false,
    double? weightKg,
    bool clearWeight = false,
    double? heightCm,
    bool clearHeight = false,
  }) async {
    if (bloodType != null && !kBloodTypes.contains(bloodType)) {
      return AppResult.failure(
        ValidationFailure('Invalid blood type: $bloodType'),
      );
    }
    if (weightKg != null && (weightKg < 1 || weightKg > 500)) {
      return AppResult.failure(
        const ValidationFailure('Weight must be between 1 and 500 kg'),
      );
    }
    if (heightCm != null && (heightCm < 30 || heightCm > 250)) {
      return AppResult.failure(
        const ValidationFailure('Height must be between 30 and 250 cm'),
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
          weightKg: weightKg,
          heightCm: heightCm,
          allergies: const [],
          conditions: const [],
          emergencyContacts: const [],
          updatedAt: DateTime.now().toUtc(),
        );
      } else {
        profile = profile.copyWith(
          bloodType: bloodType,
          clearBloodType: clearBloodType,
          weightKg: weightKg,
          clearWeight: clearWeight,
          heightCm: heightCm,
          clearHeight: clearHeight,
          updatedAt: DateTime.now().toUtc(),
        );
      }

      await _dao.upsertProfile(profile);

      final field = (clearBloodType || bloodType != null) ? 'blood_type' : 'measurements';
      _bus.publish(
        HealthProfileUpdated(userId: userId, fieldChanged: field),
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
