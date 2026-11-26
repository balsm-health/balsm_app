import 'package:core/core.dart';
import 'package:family/family.dart' show MemberTone;
import 'package:family_link/family_link.dart';
import 'package:material_ui/material_ui.dart';

import '../../app_state.dart';
import '../../kit.dart';
import 'family_kit.dart';

/// Shared pieces of the family-link screens: labels, the avatar, and the
/// failure copy.

/// A relation as a chip label (`MC_RELS[k].pick`).
String linkRelationPick(PatientAppState s, LinkRelation r) {
  final f = s.strings.family;
  return switch (r) {
    LinkRelation.son => f.pick_son,
    LinkRelation.daughter => f.pick_daughter,
    LinkRelation.mother => f.pick_mother,
    LinkRelation.father => f.pick_father,
    LinkRelation.spouse => f.pick_spouse,
    LinkRelation.neighbour => f.pick_neighbour,
    LinkRelation.friend => f.pick_friend,
    LinkRelation.other => f.pick_other,
  };
}

/// A relation as the requester reads it about the other person ("your son").
String linkRelationLabel(PatientAppState s, LinkRelation r) {
  final f = s.strings.family;
  return switch (r) {
    LinkRelation.son => f.rel_son,
    LinkRelation.daughter => f.rel_daughter,
    LinkRelation.mother => f.rel_mother,
    LinkRelation.father => f.rel_father,
    LinkRelation.spouse => f.rel_spouse(s.gender),
    LinkRelation.neighbour => f.rel_neighbour,
    LinkRelation.friend => f.rel_friend,
    LinkRelation.other => f.rel_other,
  };
}

/// The other person's name, or a neutral stand-in when neither the server nor
/// the scan gave one.
String linkName(PatientAppState s, FamilyLink link) {
  final name = link.displayName;
  return name.isEmpty ? s.strings.family.link_someone : name;
}

/// Under the name: the relation for a link this account asked for, else the
/// other person's @handle.
String linkSubtitle(PatientAppState s, FamilyLink link) {
  final handle = link.otherHandle;
  if (link.isIncoming) return handle == null || handle.isEmpty ? '' : '@$handle';
  return linkRelationLabel(s, link.relation);
}

/// The other person's avatar: their initial on a tone picked from the link id,
/// so it stays the same across pulls.
class LinkAvatar extends StatelessWidget {
  const LinkAvatar(this.link, {super.key, this.size = 46});
  final FamilyLink link;
  final double size;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final name = link.displayName;
    final tone = MemberTone.values[link.id.codeUnits.fold<int>(0, (a, b) => a + b) % MemberTone.values.length];
    return Avatar(
      initials: name.isEmpty ? '' : name.characters.first.toUpperCase(),
      color: toneColors(tone).c,
      size: size,
      fontSize: (size * 0.4).roundToDouble(),
      ar: s.rtl,
    );
  }
}

/// Copy for a failed send / approve / decline / cancel / unlink.
String linkFailureText(PatientAppState s, AppFailure failure, {bool sending = false}) {
  final f = s.strings.family;
  return switch (failure) {
    OfflineFailure() => f.link_offline(s.gender),
    NotFoundFailure() when sending => f.link_not_found(s.gender),
    ConflictFailure() when sending => f.link_exists(s.gender),
    _ => sending ? f.link_failed(s.gender) : f.link_action_failed(s.gender),
  };
}
