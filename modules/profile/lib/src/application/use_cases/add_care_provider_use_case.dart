import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/aggregates/health_profile.dart';
import '../../domain/entities/care_provider.dart';
import '../../domain/events/health_profile_updated.dart';
import '../../domain/value_objects/care_provider_type.dart';
import '../../domain/value_objects/ids.dart';
import '../../infrastructure/drift/drift_care_providers_data_source.dart';
import '../../infrastructure/drift/drift_profile_data_source.dart';
import '../ports/care_providers_data_source.dart';
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
    required CareProvidersDataSource providers,
    required EventBus eventBus,
  })  : _dao = dao,
        _providers = providers,
        _bus = eventBus;

  /// Only to resolve (or create) the profile the row hangs off.
  final HealthProfilesDataSource _dao;
  final CareProvidersDataSource _providers;
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
    String? mapUrl,
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

      final existing = await _providers.findAll(scope: profile.id);
      if (existing.length >= maxProviders) {
        return AppResult.failure(
          const ValidationFailure('Cannot add more than $maxProviders care providers'),
        );
      }

      // The caller mints the id: `put` is an upsert keyed on it, so there is
      // no add-returns-an-id round trip.
      final id = CareProviderId.uuid();
      final draft = CareProvider(
        id: id,
        healthProfileId: profile.id,
        type: type,
        name: cleanName,
        specialty: clean(specialty),
        phone: clean(phone),
        phone2: clean(phone2),
        email: clean(email),
        clinic: clean(clinic),
        address: clean(address),
        mapUrl: clean(mapUrl),
        notes: clean(notes, max: maxNotesLength),
        createdAt: DateTime.now().toUtc(),
      );
      await _providers.put(id, draft, scope: profile.id);

      _bus.publish(HealthProfileUpdated(userId: userId, fieldChanged: 'care_provider_added'));

      return AppResult.success(draft);
    } catch (e) {
      return AppResult.failure(StorageFailure(e.toString()));
    }
  }
}

final addCareProviderUseCaseProvider = Provider<AddCareProviderUseCase>((ref) {
  return AddCareProviderUseCase(
    dao: ref.watch(profileDataSourceProvider),
    providers: ref.watch(careProvidersDataSourceProvider),
    eventBus: ref.watch(eventBusProvider),
  );
});
