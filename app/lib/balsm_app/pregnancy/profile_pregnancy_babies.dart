import 'package:core/core.dart';
import 'package:family/family.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pregnancy/pregnancy.dart';
import 'package:profile/profile.dart';

/// Binds the pregnancy module's [PregnancyBabiesPort] to the profile module,
/// which owns the babies' (prenatal) profiles and their rules
/// (`HealthProfile.createMember`, `born`). Composition only — the modules
/// never import each other. PHI stays on the device; nothing here is logged.
class ProfilePregnancyBabies implements PregnancyBabiesPort {
  ProfilePregnancyBabies({required HealthProfilesDataSource profiles, required UserId? Function() activeUser})
      : _profiles = profiles,
        _activeUser = activeUser;

  final HealthProfilesDataSource _profiles;
  final UserId? Function() _activeUser;

  @override
  Stream<List<PregnancyBaby>> watchBabies(PregnancyId pregnancy) {
    final user = _activeUser();
    if (user == null) return Stream.value(const []);
    return _profiles.watchMembers(scope: user, includeClosed: true).map((rows) => _babies(rows, pregnancy));
  }

  @override
  Future<List<PregnancyBaby>> listBabies(PregnancyId pregnancy) async {
    final user = _activeUser();
    if (user == null) return const [];
    return _babies(await _profiles.findMembers(scope: user, includeClosed: true), pregnancy);
  }

  @override
  Future<AppResult<PregnancyBaby>> addBaby(PregnancyId pregnancy,
      {required int sequence, required DateTime now}) async {
    final user = _activeUser();
    if (user == null) return AppResult.failure(const UnauthorizedFailure('signed out'));
    final built = HealthProfile.createMember(
      id: HealthProfileId.uuid(),
      userId: user,
      kind: ProfileKind.prenatal,
      displayName: null,
      now: now,
      pregnancyId: pregnancy,
      sequence: sequence,
    );
    if (built.isFailure) return AppResult.failure(built.error);
    try {
      await _profiles.createMember(built.value, scope: user);
    } on StorageWriteException catch (e) {
      return AppResult.failure(StorageFailure(e.message));
    }
    return AppResult.success(pregnancyBabyOf(built.value)!);
  }

  @override
  Future<AppResult<void>> renameBaby(HealthProfileId id, String? name, {required DateTime now}) async {
    final user = _activeUser();
    if (user == null) return AppResult.failure(const UnauthorizedFailure('signed out'));
    final baby = await _openBaby(id, user);
    if (baby == null) return AppResult.failure(const NotFoundFailure());
    final trimmed = name?.trim() ?? '';
    final changed = baby.withMemberDetails(
      displayName: trimmed.isEmpty ? null : trimmed,
      dateOfBirth: null,
      sex: null,
      relationship: baby.relationship,
      groupId: baby.groupId,
      tone: baby.tone,
      sequence: baby.sequence,
      now: now,
    );
    if (changed.isFailure) return AppResult.failure(changed.error);
    final ok = await _profiles.updateMember(changed.value, scope: user);
    return ok ? AppResult.success(null) : AppResult.failure(const NotFoundFailure());
  }

  @override
  Future<AppResult<void>> closeBaby(HealthProfileId id, {required DateTime now}) async {
    final user = _activeUser();
    if (user == null) return AppResult.failure(const UnauthorizedFailure('signed out'));
    if (await _openBaby(id, user) == null) return AppResult.failure(const NotFoundFailure());
    final ok = await _profiles.closeMember(id, now, scope: user);
    return ok ? AppResult.success(null) : AppResult.failure(const NotFoundFailure());
  }

  @override
  Future<AppResult<void>> recordBirth(BirthDetails details, {required DateTime now}) async {
    final user = _activeUser();
    if (user == null) return AppResult.failure(const UnauthorizedFailure('signed out'));
    final baby = await _openBaby(details.babyId, user);
    final sex = details.sex;
    final dob = details.dateOfBirth;
    if (baby == null) return AppResult.failure(const NotFoundFailure());
    if (sex == null || dob == null) {
      return AppResult.failure(ValidationFailure(details.violations(now).map((v) => v.name).join(',')));
    }
    // The child joins the family with the next colour of the palette, as a
    // member added by hand would.
    final members = (await _profiles.findMembers(scope: user)).where((p) => p.kind == ProfileKind.dependent);
    final child = baby.born(
      displayName: details.name,
      sex: sex,
      dateOfBirth: dob,
      relationship: details.relationship,
      bloodType: details.bloodType,
      tone: MemberTone.forIndex(members.length).wire,
      now: now,
    );
    if (child.isFailure) return AppResult.failure(child.error);
    final ok = await _profiles.recordBirth(child.value, scope: user);
    return ok ? AppResult.success(null) : AppResult.failure(const NotFoundFailure());
  }

  Future<HealthProfile?> _openBaby(HealthProfileId id, UserId user) async {
    final p = await _profiles.find(id, scope: user);
    return p == null || p.kind != ProfileKind.prenatal || p.isClosed ? null : p;
  }

  static List<PregnancyBaby> _babies(List<HealthProfile> rows, PregnancyId pregnancy) => [
        for (final p in rows)
          if (p.pregnancyId == pregnancy)
            if (pregnancyBabyOf(p) case final baby?) baby
      ]..sort((a, b) => a.sequence.compareTo(b.sequence));
}

/// The pregnancy read model of a baby's [profile]; null for a profile that
/// belongs to no pregnancy or is the account holder.
PregnancyBaby? pregnancyBabyOf(HealthProfile profile) {
  final pregnancy = profile.pregnancyId;
  if (pregnancy == null || profile.isSelf) return null;
  final status = profile.kind == ProfileKind.prenatal
      ? (profile.isClosed ? BabyStatus.closed : BabyStatus.active)
      : BabyStatus.born;
  return PregnancyBaby(
    id: profile.id,
    pregnancyId: pregnancy,
    sequence: profile.sequence ?? 1,
    status: status,
    name: profile.displayName,
    dateOfBirth: status == BabyStatus.born ? profile.dateOfBirth : null,
    tone: profile.tone,
  );
}

/// The composition-root binding: `pregnancyBabiesPortProvider.overrideWith(profilePregnancyBabiesPort)`.
PregnancyBabiesPort profilePregnancyBabiesPort(Ref ref) => ProfilePregnancyBabies(
      profiles: ref.watch(profileDataSourceProvider),
      activeUser: () => ref.read(currentUserIdProvider),
    );
