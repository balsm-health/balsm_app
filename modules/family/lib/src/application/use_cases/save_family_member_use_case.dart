import 'package:core/core.dart';

import '../../domain/aggregates/member_group.dart';
import '../../domain/entities/family_member.dart';
import '../../domain/value_objects/member_draft.dart';
import '../../domain/value_objects/member_tone.dart';
import '../ports/family_members_port.dart';
import '../ports/member_groups_data_source.dart';

/// Adds a member profile (manual entry) or rewrites one's details, creating
/// the group the patient typed when there is one. Every broken form rule is
/// reported at once as a [ValidationFailure] whose message is the
/// comma-separated [MemberDraftViolation] codes.
class SaveFamilyMemberUseCase {
  const SaveFamilyMemberUseCase({required FamilyMembersPort members, required MemberGroupsDataSource groups})
      : _members = members,
        _groups = groups;

  final FamilyMembersPort _members;
  final MemberGroupsDataSource _groups;

  /// A new member, given the next tone of the palette.
  Future<AppResult<FamilyMember>> add(MemberDraft draft, {required UserId userId, required DateTime now}) async {
    final invalid = _check(draft, now);
    if (invalid != null) return AppResult.failure(invalid);
    final group = await _groupFor(draft, userId, now);
    if (group.isFailure) return AppResult.failure(group.error);
    final count = (await _members.listMembers()).length;
    return _members.createMember(draft, groupId: group.value, tone: MemberTone.forIndex(count), now: now);
  }

  /// Member [id] with [draft]'s details.
  Future<AppResult<FamilyMember>> update(
    HealthProfileId id,
    MemberDraft draft, {
    required UserId userId,
    required DateTime now,
  }) async {
    final invalid = _check(draft, now);
    if (invalid != null) return AppResult.failure(invalid);
    final group = await _groupFor(draft, userId, now);
    if (group.isFailure) return AppResult.failure(group.error);
    return _members.updateMember(id, draft, groupId: group.value, now: now);
  }

  ValidationFailure? _check(MemberDraft draft, DateTime now) {
    final v = draft.violations(now);
    return v.isEmpty ? null : ValidationFailure(v.map((e) => e.name).join(','));
  }

  Future<AppResult<MemberGroupId?>> _groupFor(MemberDraft draft, UserId userId, DateTime now) async {
    if (!draft.createsGroup) return AppResult.success(draft.groupId);
    final existing = await _groups.findAll(scope: userId);
    final last = existing.fold<int>(0, (m, g) => g.sort > m ? g.sort : m);
    final created = MemberGroup.custom(userId: userId, name: draft.newGroupName!, afterSort: last, now: now);
    if (created.isFailure) return AppResult.failure(created.error);
    await _groups.put(created.value.id, created.value, scope: userId);
    return AppResult.success(created.value.id);
  }
}
