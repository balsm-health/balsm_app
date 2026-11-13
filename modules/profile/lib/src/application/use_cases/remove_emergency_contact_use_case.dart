import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/aggregates/health_profile.dart';
import '../../domain/value_objects/ids.dart';
import '../../domain/events/health_profile_updated.dart';
import '../ports/health_profiles_data_source.dart';
import '../ports/profile_child_data_sources.dart';
import '../../infrastructure/drift/drift_profile_child_data_sources.dart';
import '../../infrastructure/drift/drift_profile_data_source.dart';

/// Removes an [EmergencyContact] from the user's [HealthProfile] (or a
/// member's) and publishes [HealthProfileUpdated] on the [EventBus].
///
/// Only a contact of the resolved profile is removed: an id that belongs to
/// someone else fails with [NotFoundFailure] and nothing changes.
///
/// PHI is mutated in the on-device SQLite/SQLCipher store only — no network
/// call, no PHI in logs.
class RemoveEmergencyContactUseCase {
  const RemoveEmergencyContactUseCase({
    required HealthProfilesDataSource dao,
    required EmergencyContactsDataSource contacts,
    required EventBus eventBus,
  })  : _dao = dao,
        _contacts = contacts,
        _bus = eventBus;

  final HealthProfilesDataSource _dao;
  final EmergencyContactsDataSource _contacts;
  final EventBus _bus;

  /// Deletes the contact [contactId] and emits an event.
  Future<AppResult<HealthProfile>> execute({
    required UserId userId,

    /// The person to change: a member profile of [userId], or null for the
    /// account holder's own (self) profile. A missing or closed member fails
    /// with [NotFoundFailure].
    HealthProfileId? profileId,
    required EmergencyContactId contactId,
  }) async {
    try {
      final profile = await _dao.resolveProfile(userId, profileId: profileId);
      if (profile == null) {
        return AppResult.failure(const NotFoundFailure('Health profile not found'));
      }
      if (!profile.emergencyContacts.any((c) => c.id == contactId)) {
        return AppResult.failure(const NotFoundFailure('Emergency contact not found'));
      }

      await _contacts.delete(contactId, scope: profile.id);

      _bus.publish(
        HealthProfileUpdated(userId: userId, fieldChanged: 'contact_removed'),
      );

      final updated = await _dao.resolveProfile(userId, profileId: profileId);
      return AppResult.success(updated ?? profile);
    } catch (e) {
      return AppResult.failure(StorageFailure(e.toString()));
    }
  }
}

final removeEmergencyContactUseCaseProvider = Provider<RemoveEmergencyContactUseCase>((ref) {
  return RemoveEmergencyContactUseCase(
    dao: ref.watch(profileDataSourceProvider),
    contacts: ref.watch(emergencyContactsDataSourceProvider),
    eventBus: ref.watch(eventBusProvider),
  );
});
