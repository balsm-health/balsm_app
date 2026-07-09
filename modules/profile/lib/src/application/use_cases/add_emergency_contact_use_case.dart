import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/aggregates/health_profile.dart';
import '../../domain/value_objects/ids.dart';
import '../../domain/events/health_profile_updated.dart';
import '../../infrastructure/drift/profile_dao.dart';

/// Adds an [EmergencyContact] to the user's [HealthProfile] and publishes
/// [HealthProfileUpdated] on the [EventBus].
///
/// Enforces the max-3-contacts rule (FR). Phone numbers are expected to be
/// already normalized to Western Arabic digits (FR-213) by the caller.
/// PHI is written to the on-device SQLite/SQLCipher store only — no network
/// call, no PHI in logs.
class AddEmergencyContactUseCase {
  const AddEmergencyContactUseCase({
    required ProfileDao dao,
    required EventBus eventBus,
  })  : _dao = dao,
        _bus = eventBus;

  final ProfileDao _dao;
  final EventBus _bus;

  /// Maximum number of emergency contacts a profile may hold.
  static const int maxContacts = 3;

  /// Validates input, persists the contact, and emits an event.
  Future<AppResult<HealthProfile>> execute({
    required UserId userId,
    required String name,
    required String phone,
    String? relation,
    bool isPrimary = false,
  }) async {
    final trimmedName = name.trim();
    final trimmedPhone = phone.trim();
    if (trimmedName.isEmpty) {
      return AppResult.failure(
        const ValidationFailure('Contact name is required'),
      );
    }
    if (trimmedPhone.isEmpty) {
      return AppResult.failure(
        const ValidationFailure('Contact phone is required'),
      );
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

      if (profile.emergencyContacts.length >= maxContacts) {
        return AppResult.failure(
          const ValidationFailure(
            'Cannot add more than $maxContacts emergency contacts',
          ),
        );
      }

      await _dao.addContact(
        profile.id,
        EmergencyContact(
          id: EmergencyContactId.uuid(),
          healthProfileId: profile.id,
          name: trimmedName,
          phone: trimmedPhone,
          relation: relation?.trim().isEmpty ?? true ? null : relation!.trim(),
          isPrimary: isPrimary,
          createdAt: DateTime.now().toUtc(),
        ),
      );

      _bus.publish(
        HealthProfileUpdated(userId: userId, fieldChanged: 'contact_added'),
      );

      final updated = await _dao.getProfile(userId);
      return AppResult.success(updated ?? profile);
    } catch (e) {
      return AppResult.failure(StorageFailure(e.toString()));
    }
  }
}

final addEmergencyContactUseCaseProvider =
    Provider<AddEmergencyContactUseCase>((ref) {
  return AddEmergencyContactUseCase(
    dao: ref.watch(profileDaoProvider),
    eventBus: ref.watch(eventBusProvider),
  );
});
