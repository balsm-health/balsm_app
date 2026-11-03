import 'package:core/core.dart';
import 'package:family/family.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:profile/profile.dart';

/// Binds the family module's [FamilyMembersPort] to the profile module, which
/// owns member profiles and their rules (`HealthProfile.createMember`,
/// `withMemberDetails`). Composition only — the two modules never import each
/// other. PHI stays on the device; nothing here is logged.
class ProfileFamilyMembers implements FamilyMembersPort {
  ProfileFamilyMembers({required HealthProfilesDataSource profiles, required UserId? Function() activeUser})
      : _profiles = profiles,
        _activeUser = activeUser;

  final HealthProfilesDataSource _profiles;
  final UserId? Function() _activeUser;

  @override
  Stream<List<FamilyMember>> watchMembers() {
    final user = _activeUser();
    if (user == null) return Stream.value(const []);
    return _profiles.watchMembers(scope: user).map(_members);
  }

  @override
  Future<List<FamilyMember>> listMembers() async {
    final user = _activeUser();
    if (user == null) return const [];
    return _members(await _profiles.findMembers(scope: user));
  }

  @override
  Future<AppResult<FamilyMember>> createMember(
    MemberDraft draft, {
    required MemberGroupId? groupId,
    required MemberTone tone,
    required DateTime now,
  }) async {
    final user = _activeUser();
    if (user == null) return AppResult.failure(const UnauthorizedFailure('signed out'));
    final built = HealthProfile.createMember(
      id: HealthProfileId.uuid(),
      userId: user,
      kind: ProfileKind.dependent,
      displayName: draft.displayName,
      now: now,
      dateOfBirth: draft.dateOfBirth,
      sex: draft.sex,
      relationship: draft.relationship,
      groupId: groupId,
      tone: tone.wire,
    );
    if (built.isFailure) return AppResult.failure(built.error);
    final member = built.value.copyWith(bloodType: draft.bloodType);
    try {
      await _profiles.createMember(member, scope: user);
    } on StorageWriteException catch (e) {
      return AppResult.failure(StorageFailure(e.message));
    }
    return AppResult.success(familyMemberOf(member));
  }

  @override
  Future<AppResult<FamilyMember>> updateMember(
    HealthProfileId id,
    MemberDraft draft, {
    required MemberGroupId? groupId,
    required DateTime now,
  }) async {
    final user = _activeUser();
    if (user == null) return AppResult.failure(const UnauthorizedFailure('signed out'));
    final existing = await _profiles.find(id, scope: user);
    if (existing == null || existing.isSelf || existing.isClosed) return AppResult.failure(const NotFoundFailure());
    final changed = existing.withMemberDetails(
      displayName: draft.displayName,
      dateOfBirth: draft.dateOfBirth,
      sex: draft.sex,
      relationship: draft.relationship,
      groupId: groupId,
      tone: existing.tone,
      sequence: existing.sequence,
      now: now,
    );
    if (changed.isFailure) return AppResult.failure(changed.error);
    if (!await _profiles.updateMember(changed.value, scope: user)) return AppResult.failure(const NotFoundFailure());
    final withBlood = changed.value.copyWith(bloodType: draft.bloodType, clearBloodType: draft.bloodType == null);
    await _profiles.put(id, withBlood, scope: user);
    return AppResult.success(familyMemberOf(withBlood));
  }

  @override
  Future<AppResult<void>> closeMember(HealthProfileId id, {required DateTime now}) async {
    final user = _activeUser();
    if (user == null) return AppResult.failure(const UnauthorizedFailure('signed out'));
    final closed = await _profiles.closeMember(id, now, scope: user);
    return closed ? AppResult.success(null) : AppResult.failure(const NotFoundFailure());
  }

  static List<FamilyMember> _members(List<HealthProfile> rows) => [
        for (final p in rows)
          if (!p.isSelf && !p.isClosed) familyMemberOf(p)
      ];
}

/// The family read model of a member [profile].
FamilyMember familyMemberOf(HealthProfile profile) => FamilyMember(
      id: profile.id,
      kind: profile.kind,
      displayName: profile.displayName ?? '',
      dateOfBirth: profile.dateOfBirth,
      sex: profile.sex,
      relationship: profile.relationship,
      groupId: profile.groupId,
      tone: MemberTone.tryFromWire(profile.tone),
      bloodType: profile.bloodType,
      status: profile.status,
    );

/// The composition-root binding: `familyMembersPortProvider.overrideWith(profileFamilyMembersPort)`.
FamilyMembersPort profileFamilyMembersPort(Ref ref) => ProfileFamilyMembers(
      profiles: ref.watch(profileDataSourceProvider),
      activeUser: () => ref.read(currentUserIdProvider),
    );
