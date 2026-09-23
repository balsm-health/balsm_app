import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/aggregates/health_profile.dart';
import '../../domain/entities/care_provider.dart';
import '../../domain/events/health_profile_updated.dart';
import '../../domain/value_objects/care_provider_type.dart';
import '../../domain/value_objects/ids.dart';
import '../../infrastructure/drift/drift_profile_data_source.dart';
import '../ports/health_profiles_data_source.dart';

/// Adds a [CareProvider] to the patient's care team and publishes
/// [HealthProfileUpdated].
///
/// Only the name is required — the design's add form says so, and a patient
/// who only remembers "the pharmacy on the corner" should still be able to
/// save it. Phone numbers are expected to arrive already normalized to Western
/// Arabic digits (FR-213), as with [AddEmergencyContactUseCase].
///
/// Written to the on-device SQLCipher store only: no network call, and no
/// provider detail in logs.
class AddCareProviderUseCase {
  const AddCareProviderUseCase({
    required HealthProfilesDataSource dao,
    required EventBus eventBus,
  })  : _dao = dao,
        _bus = eventBus;

  final HealthProfilesDataSource _dao;
  final EventBus _bus;

  /// Ceiling on care-team size. Generous — a chronic patient accumulates
  /// specialists, pharmacies and labs over years — but bounded, so a runaway
  /// caller cannot grow the table without limit.
  static const int maxProviders = 100;

  /// Longest accepted value for any single free-text field.
  static const int maxFieldLength = 200;

  /// Notes get more room: visiting hours, referral history.
  static const int maxNotesLength = 500;

  Future<AppResult<CareProvider>> execute({
    required UserId userId,
    required CareProviderType type,
    required String name,
    String? specialty,
    String? phone,
    String? phone2,
    String? email,
    String? clinic,
    String? address,
    String? notes,
  }) async {
    String? clean(String? value, {int max = maxFieldLength}) {
      final trimmed = value?.trim() ?? '';
      if (trimmed.isEmpty) return null;
      return trimmed.length > max ? trimmed.substring(0, max) : trimmed;
    }

    final cleanName = clean(name);
    if (cleanName == null) {
      return AppResult.failure(const ValidationFailure('Provider name is required'));
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

      final existing = await _dao.listProviders(profile.id);
      if (existing.length >= maxProviders) {
        return AppResult.failure(
          const ValidationFailure('Cannot add more than $maxProviders care providers'),
        );
      }

      final draft = CareProvider(
        // The DAO generates the real id; this placeholder never reaches a row.
        id: const CareProviderId.empty(),
        healthProfileId: profile.id,
        type: type,
        name: cleanName,
        specialty: clean(specialty),
        phone: clean(phone),
        phone2: clean(phone2),
        email: clean(email),
        clinic: clean(clinic),
        address: clean(address),
        notes: clean(notes, max: maxNotesLength),
        createdAt: DateTime.now().toUtc(),
      );
      final id = await _dao.addProvider(profile.id, draft);

      _bus.publish(HealthProfileUpdated(userId: userId, fieldChanged: 'care_provider_added'));

      return AppResult.success(draft.withId(id));
    } catch (e) {
      return AppResult.failure(StorageFailure(e.toString()));
    }
  }
}

final addCareProviderUseCaseProvider = Provider<AddCareProviderUseCase>((ref) {
  return AddCareProviderUseCase(
    dao: ref.watch(profileDataSourceProvider),
    eventBus: ref.watch(eventBusProvider),
  );
});
