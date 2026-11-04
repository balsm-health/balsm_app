import 'dart:math' as math;

import 'package:core/core.dart';
import 'package:family/family.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app_state.dart';
import '../../kit.dart';
import '../../responsive.dart';
import '../../shell.dart';
import '../../tokens.dart';

/// Shared pieces of the Mother & Child family screens (mother-child.jsx
/// `MC_TONES`, `MCAvatar`, `MCGroupHead`, `MCSheet`, `MCScreen`, `MCSec`,
/// `MCTile`, and the `MC_RELS` / `mcAge` labels).

/// The colours of one member tone: fill, wash, and ink on the wash.
typedef ToneColors = ({Color c, Color bg, Color ink});

ToneColors toneColors(MemberTone? tone) => switch (tone ?? MemberTone.aqua) {
      MemberTone.aqua => (c: T.hueAqua, bg: T.hueAqua50, ink: T.hueAquaInk),
      MemberTone.emerald => (c: T.hueEmerald, bg: T.hueEmerald50, ink: T.hueEmeraldInk),
      MemberTone.blue => (c: T.hueBlue, bg: T.hueBlue50, ink: T.hueBlueInk),
      MemberTone.violet => (c: T.hueViolet, bg: T.hueViolet50, ink: T.hueVioletInk),
      MemberTone.mint => (c: T.hueMint, bg: T.hueMint50, ink: T.hueMintInk),
    };

/// The account holder's avatar colour, as on Home.
const selfAvatarColor = T.hueAqua;

/// Initial of a member's short name (`mcInit`).
String memberInitial(FamilyMember m) {
  final n = m.shortName;
  return n.isEmpty ? '' : n.characters.first.toUpperCase();
}

/// `MCAvatar` for a member.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar(this.member, {super.key, this.size = 30});
  final FamilyMember member;
  final double size;
  @override
  Widget build(BuildContext context) => Avatar(
        initials: memberInitial(member),
        color: toneColors(member.tone).c,
        size: size,
        fontSize: (size * 0.4).roundToDouble(),
        ar: AppScope.of(context).rtl,
      );
}

/// `MCAvatar self` — the signed-in account holder.
class SelfAvatar extends ConsumerWidget {
  const SelfAvatar({super.key, this.size = 30});
  final double size;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = (ref.watch(accountSummaryProvider).valueOrNull?.displayName ?? '').trim();
    return Avatar(
      initials: accountInitials(name),
      color: selfAvatarColor,
      size: size,
      fontSize: (size * 0.4).roundToDouble(),
      ar: AppScope.of(context).rtl,
    );
  }
}

/// How the member relates to the account holder (`MC_RELS[rel][lang]`):
/// a child or parent is named by the member's sex when it is known.
String relationLabel(PatientAppState s, Relationship? rel, Sex? sex) {
  final f = s.strings.family;
  return switch (rel) {
    Relationship.child => switch (sex) { Sex.male => f.rel_son, Sex.female => f.rel_daughter, null => f.rel_child },
    Relationship.parent => switch (sex) { Sex.male => f.rel_father, Sex.female => f.rel_mother, null => f.rel_parent },
    Relationship.sibling => switch (sex) {
        Sex.male => f.rel_brother,
        Sex.female => f.rel_sister,
        null => f.rel_sibling
      },
    Relationship.spouse => f.rel_spouse(s.gender),
    Relationship.partner => f.rel_partner,
    Relationship.grandparent => f.rel_grandparent,
    Relationship.relative => f.rel_relative,
    Relationship.friend => f.rel_friend,
    Relationship.neighbour => f.rel_neighbour,
    Relationship.guardian => f.rel_guardian,
    Relationship.caregiver => f.rel_caregiver,
    Relationship.other || null => f.rel_other,
  };
}

/// `mcAge` — months for a baby, "1 year 3 months" under two, years after.
String ageLabel(PatientAppState s, MemberAge age) {
  final f = s.strings.family;
  if (age.years == 0) return f.age_months(age.months);
  if (age.years < 2 && age.months > 0) return f.age_and(f.age_years(age.years), f.age_months(age.months));
  return f.age_years(age.years);
}

/// "{relation} · {age}" — the member's subtitle in lists.
String memberSubtitle(PatientAppState s, FamilyMember m, DateTime now) {
  final age = m.ageOn(now);
  return [relationLabel(s, m.relationship, m.sex), if (age != null) ageLabel(s, age)].join(' · ');
}

/// `mcFmt` — DD/MM/YYYY, read left to right in both languages.
String formatDay(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year.toString().padLeft(4, '0')}';

/// A group's name: a default group in the patient's language, otherwise the
/// name they gave it.
String groupLabel(PatientAppState s, MemberGroup g) => switch (g.defaultGroup) {
      DefaultGroup.family => s.strings.family.group_family,
      DefaultGroup.neighbours => s.strings.family.group_neighbours,
      null => g.name ?? '',
    };

/// `MCGroupHead` — group name and its member count.
class GroupHead extends StatelessWidget {
  const GroupHead({super.key, required this.label, required this.count});
  final String label;
  final int count;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 16, 4, 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Expanded(
          child: Text(label, style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg2)),
        ),
        Text('$count', style: Typo.meta(ar: s.rtl)),
      ]),
    );
  }
}

/// `MCSheet` — white bottom sheet with a grab, a title, an optional
/// subtitle, a close button and a scrolling body.
class FamilySheet extends StatelessWidget {
  const FamilySheet({super.key, required this.title, this.sub, required this.children});
  final String title;
  final String? sub;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(T.rXl)),
      ),
      // Clear the home indicator and, while typing, the keyboard.
      padding: EdgeInsets.only(
          bottom: math.max(MediaQuery.paddingOf(context).bottom, 16.0) + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 10),
        const SheetGrab(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(crossAxisAlignment: sub == null ? CrossAxisAlignment.center : CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700)),
                if (sub != null) ...[
                  const SizedBox(height: 4),
                  Text(sub!, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
                ],
              ]),
            ),
            const SizedBox(width: 12),
            RoundBtn(
              icon: LucideIcons.x,
              semanticLabel: s.strings.common.a11y_close,
              ghost: true,
              iconSize: 17,
              onTap: () => Navigator.pop(context),
            ),
          ]),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ),
      ]),
    );
  }
}

/// `MCScreen` — back + title app bar, an optional bar under it (the profile
/// bar), a width-capped scrolling body and an optional pinned footer.
class FamilyScaffold extends StatelessWidget {
  const FamilyScaffold({
    super.key,
    required this.title,
    required this.children,
    this.onBack,
    this.trailing,
    this.bar,
    this.footer,
    this.onRefresh,
  });
  final String title;
  final List<Widget> children;
  final VoidCallback? onBack;
  final Widget? trailing;
  final Widget? bar;
  final Widget? footer;

  /// Pull-to-refresh on the body, when given.
  final Future<void> Function()? onRefresh;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(children: [
        const PadTop(),
        AppBarRow(
          leading: RoundBtn(
            icon: backArrow(context),
            semanticLabel: s.strings.common.a11y_back,
            onTap: onBack ?? () => Navigator.pop(context),
          ),
          children: [
            Expanded(
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Typo.heading(ar: s.rtl).copyWith(fontSize: FS.xl)),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        if (bar != null) bar!,
        Expanded(
          child: ContentColumn(
            maxWidth: 640,
            child: onRefresh == null
                ? ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 40), children: children)
                : RefreshIndicator(
                    onRefresh: onRefresh!,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                      children: children,
                    ),
                  ),
          ),
        ),
        if (footer != null)
          Container(
            padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.paddingOf(context).bottom + 26),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: T.ink100)),
            ),
            child: ContentColumn(maxWidth: 640, child: footer!),
          ),
      ]),
    );
  }
}

/// `MCSec` — a section heading inside a family screen.
class FamilySecHead extends StatelessWidget {
  const FamilySecHead(this.title, {super.key});
  final String title;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Text(title, style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700)),
    );
  }
}

/// `MCTile` — icon on a tone wash, title, one line under it.
class FamilyTile extends StatelessWidget {
  const FamilyTile({
    super.key,
    required this.icon,
    required this.tone,
    required this.title,
    required this.sub,
    required this.onTap,
  });
  final IconData icon;
  final MemberTone tone;
  final String title;
  final String sub;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final t = toneColors(tone);
    return Semantics(
      button: true,
      child: PCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 88),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            IconSquare(icon, bg: t.bg, fg: t.ink, size: 40, iconSize: 20),
            const SizedBox(height: 10),
            Text(title, style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
            Text(sub, style: Typo.meta(ar: s.rtl)),
          ]),
        ),
      ),
    );
  }
}

/// The "data stays on this phone" line.
class StaysLocalNote extends StatelessWidget {
  const StaysLocalNote({super.key, this.center = true});
  final bool center;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        mainAxisAlignment: center ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          const Icon(LucideIcons.lock, size: 13, color: T.fg3),
          const SizedBox(width: 6),
          Flexible(child: Text(s.strings.family.stays_local, style: Typo.meta(ar: s.rtl))),
        ],
      ),
    );
  }
}

/// Pushes a family screen as a full-screen route inside the app's
/// directionality and the tablet/desktop frame, like the profile sub-screens.
Future<R?> pushFamilyScreen<R>(BuildContext context, Widget Function(PatientAppState s) build) {
  final s = AppScope.of(context);
  return Navigator.of(context, rootNavigator: true).push<R>(MaterialPageRoute(
    builder: (_) => Directionality(textDirection: s.dir, child: AdaptiveFrame(child: build(s))),
  ));
}
