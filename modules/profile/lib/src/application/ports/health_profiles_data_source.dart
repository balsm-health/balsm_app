import 'package:core/core.dart';

import '../../domain/aggregates/health_profile.dart';

/// Persistence port for health profiles and their child collections.
///
/// Pure contract — core's [UserDataSource] scope semantics (partition = the
/// OWNING account, key = the profile). An account owns exactly one self
/// profile (`isSelf`) plus any member profiles (dependent / prenatal) it
/// manages; generic reads ([findAll], [watchAll]) list them self first, then
/// members in creation order, closed ones included. No storage technology
/// leaks here: the drift-backed implementation lives in
/// `infrastructure/drift/` and is bound via `profileDataSourceProvider`.
///
/// Reads hydrate the full aggregate (allergies, conditions, contacts). `put`
/// writes the head row only (blood type, measurements); member details and
/// the lifecycle change only through [createMember], [updateMember] and
/// [closeMember], so a stale aggregate can never re-open or re-kind a
/// profile. The care team is NOT part of this aggregate: a care provider is
/// its own key/value pair and gets the generic contract in its own right —
/// see `CareProvidersDataSource`.
abstract class HealthProfilesDataSource extends UserDataSource<HealthProfileId, HealthProfile>
    implements WatchableScopedDataSource<HealthProfileId, HealthProfile, UserId> {
  /// The user's SELF profile (`isSelf`), or null if none exists yet. Never a
  /// member profile, however many the account has.
  Future<HealthProfile?> getProfile(UserId userId);

  /// Emits the self profile and updates whenever the row changes.
  Stream<HealthProfile?> watchProfile(UserId userId);

  /// Inserts or updates the head row for [profile]. Does NOT persist child
  /// collections — use the individual add*/remove* methods.
  Future<void> upsertProfile(HealthProfile profile);

  /// The account's profiles for the profile switcher / family list: self
  /// first, then members in creation order. Closed members only when
  /// [includeClosed].
  Future<List<HealthProfile>> findMembers({UserId? scope, bool includeClosed = false});

  /// Stores a new member profile built by `HealthProfile.createMember`
  /// (dependent or prenatal; never self). Throws [StorageWriteException] when
  /// the id already exists or [member] is a self profile.
  Future<void> createMember(HealthProfile member, {UserId? scope});

  /// Writes [member]'s details (name, date of birth, sex, relationship,
  /// group, tone, sequence) — from `HealthProfile.withMemberDetails`. Kind,
  /// status and the self flag are left untouched. Returns false when no open
  /// member profile with that id exists in the partition.
  Future<bool> updateMember(HealthProfile member, {UserId? scope});

  /// Closes the member profile [id] on [closedOn] (soft: every record it
  /// holds is kept). Refuses the self profile and an already-closed one by
  /// returning false. Callers then refresh core's active profile
  /// (`activeProfileSwitcherProvider.refresh()`), which falls back to self
  /// when the closed profile was selected.
  Future<bool> closeMember(HealthProfileId id, DateTime closedOn, {UserId? scope});
}
