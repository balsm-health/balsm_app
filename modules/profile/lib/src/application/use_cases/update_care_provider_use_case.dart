import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/care_provider.dart';
import '../../domain/events/health_profile_updated.dart';
import '../../domain/value_objects/care_provider_type.dart';
import '../../infrastructure/drift/drift_profile_data_source.dart';
import '../ports/health_profiles_data_source.dart';
import 'add_care_provider_use_case.dart';

/// Edits an existing [CareProvider] in place.
///
/// `home.jsx` turned the care-team card's remove button into an edit button —
/// a provider's phone or clinic changes far more often than the provider does,
/// and re-adding them lost their attached files. Editing keeps the row id, so
/// the files stay attached.
///
/// Field rules are [AddCareProviderUseCase]'s: only the name is required,
/// values are trimmed, and anything past the length ceiling is truncated
/// rather than rejected. Phone numbers arrive already normalized (FR-213).
///
/// On-device SQLCipher only: no network call, and no provider detail in logs.
class UpdateCareProviderUseCase {
  const UpdateCareProviderUseCase({
    required HealthProfilesDataSource dao,
    required EventBus eventBus,
  })  : _dao = dao,
        _bus = eventBus;

  final HealthProfilesDataSource _dao;
  final EventBus _bus;

  Future<AppResult<CareProvider>> execute({
    required UserId userId,
    required CareProvider provider,
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
    String? clean(String? value, {int max = AddCareProviderUseCase.maxFieldLength}) {
      final trimmed = value?.trim() ?? '';
      if (trimmed.isEmpty) return null;
      return trimmed.length > max ? trimmed.substring(0, max) : trimmed;
    }

    final cleanName = clean(name);
    if (cleanName == null) {
      return AppResult.failure(const ValidationFailure('Provider name is required'));
    }

    try {
      final updated = CareProvider(
        id: provider.id,
        healthProfileId: provider.healthProfileId,
        type: type,
        name: cleanName,
        specialty: clean(specialty),
        phone: clean(phone),
        phone2: clean(phone2),
        email: clean(email),
        clinic: clean(clinic),
        address: clean(address),
        mapUrl: clean(mapUrl),
        notes: clean(notes, max: AddCareProviderUseCase.maxNotesLength),
        // The row keeps the date it was first saved.
        createdAt: provider.createdAt,
      );
      await _dao.updateProvider(provider.id, updated);

      _bus.publish(HealthProfileUpdated(userId: userId, fieldChanged: 'care_provider_updated'));

      return AppResult.success(updated);
    } catch (e) {
      return AppResult.failure(StorageFailure(e.toString()));
    }
  }
}

final updateCareProviderUseCaseProvider = Provider<UpdateCareProviderUseCase>((ref) {
  return UpdateCareProviderUseCase(
    dao: ref.watch(profileDataSourceProvider),
    eventBus: ref.watch(eventBusProvider),
  );
});
