import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/events/health_profile_updated.dart';
import '../../domain/value_objects/ids.dart';
import '../../infrastructure/drift/drift_care_providers_data_source.dart';
import '../ports/care_providers_data_source.dart';

/// Removes one member from the patient's care team.
///
/// A hard delete: the row is the patient's own note about who treats them, so
/// "remove" means gone, not tombstoned. Idempotent — deleting an id that is
/// already absent succeeds.
class RemoveCareProviderUseCase {
  const RemoveCareProviderUseCase({
    required CareProvidersDataSource providers,
    required EventBus eventBus,
  })  : _providers = providers,
        _bus = eventBus;

  final CareProvidersDataSource _providers;
  final EventBus _bus;

  Future<AppResult<void>> execute({required UserId userId, required CareProviderId providerId}) async {
    try {
      await _providers.delete(providerId);
      _bus.publish(HealthProfileUpdated(userId: userId, fieldChanged: 'care_provider_removed'));
      return AppResult.success(null);
    } catch (e) {
      return AppResult.failure(StorageFailure(e.toString()));
    }
  }
}

final removeCareProviderUseCaseProvider = Provider<RemoveCareProviderUseCase>((ref) {
  return RemoveCareProviderUseCase(
    providers: ref.watch(careProvidersDataSourceProvider),
    eventBus: ref.watch(eventBusProvider),
  );
});
