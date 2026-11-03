import 'package:core/core.dart';

import '../ports/family_members_port.dart';

/// Closes a member profile (soft: its records stay, read-only), then lets
/// core re-resolve the active profile — which falls back to self when the
/// closed member was the one selected.
class CloseFamilyMemberUseCase {
  const CloseFamilyMemberUseCase({required FamilyMembersPort members, required void Function() refreshActive})
      : _members = members,
        _refreshActive = refreshActive;

  final FamilyMembersPort _members;
  final void Function() _refreshActive;

  Future<AppResult<void>> call(HealthProfileId id, {required DateTime now}) async {
    final result = await _members.closeMember(id, now: now);
    if (result.isSuccess) _refreshActive();
    return result;
  }
}
