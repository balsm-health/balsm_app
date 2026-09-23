import 'package:core/core.dart';

import '../../domain/aggregates/health_profile.dart';
import '../../domain/entities/care_provider.dart';
import '../../domain/value_objects/ids.dart';

/// Persistence port for health profiles and their child collections.
///
/// Pure contract — core's [UserDataSource] scope semantics (partition = the
/// OWNING account, key = the profile; today one self profile per account,
/// dependant siblings arrive with P00X and `findAll()` becomes the
/// profile-switcher's source). No storage technology leaks here: the
/// drift-backed implementation lives in `infrastructure/drift/` and is bound
/// via `profileDataSourceProvider`.
///
/// Reads hydrate the full aggregate (allergies, conditions, contacts);
/// `put` persists the head row only — children go through the dedicated
/// add*/remove* operations. The care team is deliberately NOT part of the
/// aggregate: it is a list the care-team screen watches on its own, and
/// hydrating it into every profile read would cost every caller a join it
/// does not use.
abstract class HealthProfilesDataSource extends UserDataSource<HealthProfileId, HealthProfile>
    implements WatchableScopedDataSource<HealthProfileId, HealthProfile, UserId> {
  /// The user's (self) profile, or null if none exists yet.
  Future<HealthProfile?> getProfile(UserId userId);

  /// Emits the current profile and updates whenever the row changes.
  Stream<HealthProfile?> watchProfile(UserId userId);

  /// Inserts or updates the head row for [profile]. Does NOT persist child
  /// collections — use the individual add*/remove* methods.
  Future<void> upsertProfile(HealthProfile profile);

  /// Inserts [allergy] under [profileId]. Returns the generated [AllergyId].
  Future<AllergyId> addAllergy(HealthProfileId profileId, Allergy allergy);

  /// Deletes the allergy row with the given [allergyId].
  Future<void> removeAllergy(AllergyId allergyId);

  /// Inserts [condition] under [profileId]. Returns the generated
  /// [ChronicConditionId].
  Future<ChronicConditionId> addCondition(HealthProfileId profileId, ChronicCondition condition);

  /// Deletes the chronic-condition row with the given [conditionId].
  Future<void> removeCondition(ChronicConditionId conditionId);

  /// Inserts [contact] under [profileId]. Returns the generated
  /// [EmergencyContactId].
  Future<EmergencyContactId> addContact(HealthProfileId profileId, EmergencyContact contact);

  /// The care team under [profileId], oldest first.
  Future<List<CareProvider>> listProviders(HealthProfileId profileId);

  /// Emits the care team under [profileId] and again on every change.
  Stream<List<CareProvider>> watchProviders(HealthProfileId profileId);

  /// Inserts [provider] under [profileId]. Returns the generated
  /// [CareProviderId].
  Future<CareProviderId> addProvider(HealthProfileId profileId, CareProvider provider);

  /// Deletes the care-provider row with the given [providerId]; its files go
  /// with it (`ON DELETE CASCADE`).
  Future<void> removeProvider(CareProviderId providerId);

  /// Vault-relative paths of [providerId]'s files, oldest first.
  Future<List<String>> listProviderFiles(CareProviderId providerId);

  /// Emits [providerId]'s file paths and again on every change.
  Stream<List<String>> watchProviderFiles(CareProviderId providerId);

  /// Attaches the vault file at [path] to [providerId].
  Future<void> addProviderFile(CareProviderId providerId, String path);

  /// Detaches [path] from [providerId]. The vault blob itself is the caller's
  /// to delete — a path may be referenced more than once.
  Future<void> removeProviderFile(CareProviderId providerId, String path);
}
