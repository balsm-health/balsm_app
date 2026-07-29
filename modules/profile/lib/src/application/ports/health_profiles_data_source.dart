import 'package:core/core.dart';

import '../../domain/aggregates/health_profile.dart';
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
/// add*/remove* operations.
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

  /// Inserts [contact] under [profileId]. Returns the generated
  /// [EmergencyContactId].
  Future<EmergencyContactId> addContact(HealthProfileId profileId, EmergencyContact contact);
}
