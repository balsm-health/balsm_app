import 'package:core/core.dart';

import '../../domain/aggregates/health_profile.dart';

/// Persistence port for health profiles and their child collections.
///
/// Pure contract — core's [UserDataSource] scope semantics (partition = the
/// OWNING account, key = the profile; today one self profile per account,
/// dependant siblings arrive with P00X and `findAll()` becomes the
/// profile-switcher's source). No storage technology leaks here: the
/// drift-backed implementation lives in `infrastructure/drift/` and is bound
/// via `profileDataSourceProvider`.
///
/// Reads hydrate the full aggregate (allergies, conditions, contacts) and
/// `put` writes it back, children included — so the two halves agree and the
/// contract needs no add*/remove* methods of its own. Last-write-wins: `put`
/// deletes stored children absent from the value, so pass an aggregate you
/// actually read. The care team is NOT part of this aggregate: a care provider
/// is its own key/value pair and gets the generic contract in its own right —
/// see `CareProvidersDataSource`.
abstract class HealthProfilesDataSource extends UserDataSource<HealthProfileId, HealthProfile>
    implements WatchableScopedDataSource<HealthProfileId, HealthProfile, UserId> {
  /// The user's (self) profile, or null if none exists yet.
  Future<HealthProfile?> getProfile(UserId userId);

  /// Emits the current profile and updates whenever the row changes.
  Stream<HealthProfile?> watchProfile(UserId userId);

  /// Inserts or updates the head row for [profile]. Does NOT persist child
  /// collections — use the individual add*/remove* methods.
  Future<void> upsertProfile(HealthProfile profile);
}
