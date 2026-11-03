import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/family_member.dart';
import '../../domain/value_objects/member_draft.dart';
import '../../domain/value_objects/member_tone.dart';

/// The signed-in account's member profiles, read and written for the family
/// screens.
///
/// Member profiles are Personal Health roots owned by the profile module
/// (`HealthProfile.createMember` holds their rules). This module may not
/// import it, so it declares the port and the app composition root binds it
/// to the profile module's data source — the same seam as emergency_card's
/// `EmergencySnapshotReader`. Everything stays on the device.
abstract interface class FamilyMembersPort {
  /// Open member profiles (never self, never closed), in creation order.
  /// Emits now and again after each change; empty while signed out.
  Stream<List<FamilyMember>> watchMembers();

  /// One read of [watchMembers].
  Future<List<FamilyMember>> listMembers();

  /// Stores a new dependent profile from [draft], filed under [groupId] with
  /// [tone]. A [ValidationFailure] carries the broken rule codes.
  Future<AppResult<FamilyMember>> createMember(
    MemberDraft draft, {
    required MemberGroupId? groupId,
    required MemberTone tone,
    required DateTime now,
  });

  /// Rewrites member [id]'s details from [draft]. [NotFoundFailure] when [id]
  /// is not an open member of the signed-in account.
  Future<AppResult<FamilyMember>> updateMember(
    HealthProfileId id,
    MemberDraft draft, {
    required MemberGroupId? groupId,
    required DateTime now,
  });

  /// Closes member [id] (soft: every record it holds is kept, read-only).
  /// [NotFoundFailure] when it is not an open member.
  Future<AppResult<void>> closeMember(HealthProfileId id, {required DateTime now});
}

/// Bound in the app composition root (`bootstrap()`) to the profile-backed
/// adapter via `overrideWith`.
final familyMembersPortProvider = Provider<FamilyMembersPort>(
  (ref) => throw UnimplementedError('familyMembersPortProvider must be overridden in bootstrap()'),
);
