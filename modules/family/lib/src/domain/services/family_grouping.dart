import 'package:core/core.dart';

import '../aggregates/member_group.dart';
import '../entities/family_member.dart';
import '../value_objects/default_group.dart';

/// One group and the members filed under it.
class FamilySection {
  const FamilySection(this.group, this.members);

  final MemberGroup group;
  final List<FamilyMember> members;
}

/// Sorts [members] into [groups] (design `mcGrouped`): groups in their
/// display order, members in the order given, empty groups left out.
///
/// A member whose group is missing or deleted falls under the family
/// default group. When two default groups share a key — a device-only
/// account merged into an online one brings its own — the first by sort is
/// kept and the other's members join it.
List<FamilySection> groupFamily(List<MemberGroup> groups, List<FamilyMember> members) {
  final ordered = [...groups]..sort((a, b) => a.sort.compareTo(b.sort));
  final kept = <MemberGroup>[];
  final alias = <MemberGroupId, MemberGroupId>{};
  final byKey = <DefaultGroup, MemberGroup>{};
  for (final g in ordered) {
    final key = g.defaultGroup;
    final first = key == null ? null : byKey[key];
    if (first != null) {
      alias[g.id] = first.id;
      continue;
    }
    if (key != null) byKey[key] = g;
    kept.add(g);
  }
  final fallback = byKey[DefaultGroup.family]?.id ?? (kept.isEmpty ? null : kept.first.id);
  final known = {for (final g in kept) g.id};

  MemberGroupId? home(FamilyMember m) {
    final id = m.groupId == null ? null : (alias[m.groupId!] ?? m.groupId!);
    return id != null && known.contains(id) ? id : fallback;
  }

  return [
    for (final g in kept)
      if (members.where((m) => home(m) == g.id).toList() case final list when list.isNotEmpty) FamilySection(g, list),
  ];
}
