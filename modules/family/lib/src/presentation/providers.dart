import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/ports/family_members_port.dart';
import '../application/use_cases/close_family_member_use_case.dart';
import '../application/use_cases/ensure_default_groups_use_case.dart';
import '../application/use_cases/save_family_member_use_case.dart';
import '../domain/aggregates/member_group.dart';
import '../domain/entities/family_member.dart';
import '../domain/services/family_grouping.dart';
import '../infrastructure/drift/drift_member_groups_data_source.dart';

/// The signed-in account's open member profiles, live. Empty while signed
/// out; re-subscribes when the account changes.
final familyMembersProvider = StreamProvider<List<FamilyMember>>((ref) {
  if (ref.watch(currentUserIdProvider) == null) return Stream.value(const []);
  return ref.watch(familyMembersPortProvider).watchMembers();
});

/// The account's groups in display order, live. The default groups are
/// created on the first read for an account.
final memberGroupsProvider = StreamProvider<List<MemberGroup>>((ref) async* {
  final user = ref.watch(currentUserIdProvider);
  if (user == null) {
    yield const [];
    return;
  }
  final groups = ref.watch(memberGroupsDataSourceProvider);
  await EnsureDefaultGroupsUseCase(groups)(user, now: DateTime.now());
  yield* groups.watchAll(scope: user);
});

/// Managed members (dependents) sorted into their groups, for the family list
/// and the people picker. Null until both the members and the groups have
/// loaded, so a screen never flashes "no members yet" on its way in.
final familySectionsProvider = Provider<List<FamilySection>?>((ref) {
  final members = ref.watch(familyMembersProvider).valueOrNull;
  final groups = ref.watch(memberGroupsProvider).valueOrNull;
  if (members == null || groups == null) return null;
  return groupFamily(groups, members.where((m) => m.kind == ProfileKind.dependent).toList());
});

/// The member whose data the app is showing, or null when it is the account
/// holder's own (core's `currentProfileIdProvider` is the self profile).
final activeFamilyMemberProvider = Provider<FamilyMember?>((ref) {
  final active = ref.watch(currentProfileIdProvider);
  if (active == null) return null;
  final members = ref.watch(familyMembersProvider).valueOrNull ?? const <FamilyMember>[];
  return members.where((m) => m.id == active).firstOrNull;
});

final saveFamilyMemberUseCaseProvider = Provider<SaveFamilyMemberUseCase>(
  (ref) => SaveFamilyMemberUseCase(
    members: ref.watch(familyMembersPortProvider),
    groups: ref.watch(memberGroupsDataSourceProvider),
  ),
);

final closeFamilyMemberUseCaseProvider = Provider<CloseFamilyMemberUseCase>(
  (ref) => CloseFamilyMemberUseCase(
    members: ref.watch(familyMembersPortProvider),
    refreshActive: () => ref.read(activeProfileSwitcherProvider).refresh(),
  ),
);
