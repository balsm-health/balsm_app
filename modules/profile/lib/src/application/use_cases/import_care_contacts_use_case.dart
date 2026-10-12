import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/aggregates/health_profile.dart';
import '../../domain/entities/care_provider.dart';
import '../../domain/entities/imported_contact.dart';
import '../../domain/events/health_profile_updated.dart';
import '../../domain/value_objects/ids.dart';
import '../../infrastructure/drift/drift_care_providers_data_source.dart';
import '../../infrastructure/drift/drift_profile_data_source.dart';
import '../ports/care_providers_data_source.dart';
import '../ports/health_profiles_data_source.dart';

/// Turns contacts the patient picked from the phone's address book into
/// care-team records.
///
/// Writes through [CareProvidersDataSource] like any other care-team change, so
/// an imported row queues a cloud push exactly as a hand-typed one does. There
/// is no separate import path to the server and no network call here.
class ImportCareContactsUseCase {
  const ImportCareContactsUseCase({
    required HealthProfilesDataSource dao,
    required CareProvidersDataSource providers,
    required EventBus eventBus,
  })  : _dao = dao,
        _providers = providers,
        _bus = eventBus;

  final HealthProfilesDataSource _dao;
  final CareProvidersDataSource _providers;
  final EventBus _bus;

  /// Same ceiling the manual add enforces.
  static const int maxProviders = 100;

  /// Longest accepted value for any single free-text field.
  static const int maxFieldLength = 200;

  /// Imports [contacts], returning the rows actually created.
  ///
  /// Skips silently rather than failing, in three cases: a contact already on
  /// the team (matched on phone), a blank name, and anything past
  /// [maxProviders]. A patient near the ceiling who picks five more gets the
  /// ones that fit — refusing the whole batch would lose the work of choosing.
  /// The caller compares the returned length against what it offered to tell
  /// the patient what landed.
  Future<AppResult<List<CareProvider>>> execute({
    required UserId userId,
    required List<ImportedContact> contacts,
  }) async {
    if (contacts.isEmpty) return AppResult.success(const []);

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
      var room = maxProviders - existing.length;
      if (room <= 0) return AppResult.success(const []);

      // Grows as we go: two picked contacts that are the same number must not
      // both land, and the second is a duplicate of the first, not of storage.
      final seen = <CareProvider>[...existing];
      final drafts = <CareProviderId, CareProvider>{};
      final created = <CareProvider>[];
      final now = DateTime.now().toUtc();

      for (final contact in contacts) {
        if (room == 0) break;
        if (contact.name.trim().isEmpty) continue;
        if (contact.isAlreadyOnTeam(seen)) continue;

        final row = contact.toCareProvider(profile.id, createdAt: now);
        final name = row.name.length > maxFieldLength ? row.name.substring(0, maxFieldLength) : row.name;

        final id = CareProviderId.uuid();
        final draft = CareProvider(
          id: id,
          healthProfileId: row.healthProfileId,
          type: row.type,
          name: name,
          phone: row.phone,
          phone2: row.phone2,
          email: row.email,
          createdAt: row.createdAt,
        );

        drafts[id] = draft;
        created.add(draft);
        seen.add(draft);
        room--;
      }

      if (drafts.isEmpty) return AppResult.success(const []);

      await _providers.putBulk(drafts, scope: profile.id);

      // One event for the batch: the care team changed once, however many rows
      // that took.
      _bus.publish(HealthProfileUpdated(userId: userId, fieldChanged: 'care_providers_imported'));

      return AppResult.success(created);
    } catch (e) {
      return AppResult.failure(StorageFailure(e.toString()));
    }
  }
}

final importCareContactsUseCaseProvider = Provider<ImportCareContactsUseCase>((ref) {
  return ImportCareContactsUseCase(
    dao: ref.watch(profileDataSourceProvider),
    providers: ref.watch(careProvidersDataSourceProvider),
    eventBus: ref.watch(eventBusProvider),
  );
});
