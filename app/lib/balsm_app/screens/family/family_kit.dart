import 'dart:math' as math;

import 'package:core/core.dart';
import 'package:family/family.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../app_state.dart';
import '../../kit.dart';
import '../../responsive.dart';
import '../../shell.dart';

/// Shared pieces of the Mother & Child family screens (mother-child.jsx
/// `MC_TONES`, `MCAvatar`, `MCGroupHead`, `MCSheet`, `MCScreen`, `MCSec`,
/// `MCTile`, and the `MC_RELS` / `mcAge` labels).

/// The colours of one member tone: fill, wash, and ink on the wash.
typedef ToneColors = ({Color c, Color bg, Color ink});

ToneColors toneColors(MemberTone? tone) => switch (tone ?? MemberTone.aqua) {
      MemberTone.aqua => (c: AppColors.hueAqua, bg: AppColors.hueAqua50, ink: AppColors.hueAquaInk),
      MemberTone.emerald => (c: AppColors.hueEmerald, bg: AppColors.hueEmerald50, ink: AppColors.hueEmeraldInk),
      MemberTone.blue => (c: AppColors.hueBlue, bg: AppColors.hueBlue50, ink: AppColors.hueBlueInk),
      MemberTone.violet => (c: AppColors.hueViolet, bg: AppColors.hueViolet50, ink: AppColors.hueVioletInk),
      MemberTone.mint => (c: AppColors.hueMint, bg: AppColors.hueMint50, ink: AppColors.hueMintInk),
    };

/// The account holder's avatar colour, as on Home.
const Color selfAvatarColor = AppColors.hueAqua;

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
    final name = (ref.watch(accountSummaryProvider).value?.displayName ?? '').trim();
    return Avatar(
      initials: accountInitials(name),
      color: selfAvatarColor,
      semanticLabel: AppScope.of(context).strings.home.a11y_self_avatar,
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
    Relationship.spouse => switch (sex) {
        Sex.female => f.rel_wife,
        Sex.male => f.rel_husband,
        null => f.rel_spouse(s.gender)
      },
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
  const GroupHead({required this.label, required this.count, super.key});
  final String label;
  final int count;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 16, 4, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              label,
              style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: AppColors.textSecondary),
            ),
          ),
          Text('$count', style: Typo.meta(ar: s.rtl)),
        ],
      ),
    );
  }
}

/// `MCSheet` — white bottom sheet with a grab, a title, an optional
/// subtitle, a close button and a scrolling body.
class FamilySheet extends StatelessWidget {
  const FamilySheet({required this.title, required this.children, super.key, this.sub});
  final String title;
  final String? sub;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      // Clear the home indicator and, while typing, the keyboard.
      padding: EdgeInsets.only(
        bottom: math.max(MediaQuery.paddingOf(context).bottom, 16) + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          const SheetGrab(),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 12),
            child: Row(
              crossAxisAlignment: sub == null ? CrossAxisAlignment.center : CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700)),
                      if (sub case final sub?) ...[
                        const SizedBox(height: 4),
                        Text(sub, style: Typo.bodySm(ar: s.rtl).copyWith(color: AppColors.textTertiary)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                RoundBtn(
                  icon: LucideIcons.x,
                  semanticLabel: s.strings.common.a11y_close,
                  ghost: true,
                  iconSize: 17,
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
            ),
          ),
        ],
      ),
    );
  }
}

/// Asks [title] / [body] in a [FamilyConfirmSheet] before a delete; true
/// when the patient confirmed. [confirmLabel] defaults to "Delete".
Future<bool> showFamilyConfirmSheet(
  BuildContext context, {
  required String title,
  required String body,
  String? confirmLabel,
}) async {
  final s = AppScope.of(context);
  final yes = await showAppSheet<bool>(
    context,
    textDirection: s.dir,
    builder: (_) => FamilyConfirmSheet(title: title, body: body, confirmLabel: confirmLabel),
  );
  return yes == true;
}

/// Asks to close member [m]'s profile in a [FamilyConfirmSheet] (the
/// mother-child.jsx `MCEditMemberScreen` delete-profile confirm; the app
/// soft-closes instead of deleting, so the copy says the records stay), then
/// closes it. Shows the outcome in a snackbar; true once the profile is closed.
Future<bool> confirmCloseMember(BuildContext context, WidgetRef ref, FamilyMember m) async {
  final s = AppScope.of(context);
  final f = s.strings.family;
  final yes = await showFamilyConfirmSheet(
    context,
    title: f.close_confirm_t(m.shortName),
    body: f.close_confirm_b,
    confirmLabel: f.close_profile,
  );
  if (!yes || !context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);
  final result = await ref.read(closeFamilyMemberUseCaseProvider)(m.id, now: DateTime.now());
  messenger
      .showSnackBar(SnackBar(content: Text(result.isSuccess ? f.closed_toast(m.shortName) : f.save_failed(s.gender))));
  return result.isSuccess;
}

/// MCConfirmSheet — mother-child.jsx: the small sheet that confirms a delete.
/// The question and what deleting means, then a full-width danger button and
/// Cancel, stacked so long Arabic labels never truncate. Pops `true` on
/// confirm, `false` on cancel.
class FamilyConfirmSheet extends StatelessWidget {
  const FamilyConfirmSheet({required this.title, required this.body, super.key, this.confirmLabel});
  final String title;
  final String body;

  /// The danger button's label; "Delete" when null.
  final String? confirmLabel;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return FamilySheet(
      title: title,
      sub: body,
      children: [
        const SizedBox(height: 4),
        PButton(
          confirmLabel ?? s.strings.common.del,
          variant: BtnVariant.danger,
          large: true,
          block: true,
          ar: s.rtl,
          onTap: () => Navigator.pop(context, true),
        ),
        const SizedBox(height: 10),
        PButton(
          s.strings.common.cancel,
          variant: BtnVariant.secondary,
          large: true,
          block: true,
          ar: s.rtl,
          onTap: () => Navigator.pop(context, false),
        ),
      ],
    );
  }
}

/// `MCScreen` — back + title app bar, an optional bar under it (the profile
/// bar), a width-capped scrolling body and an optional pinned footer.
class FamilyScaffold extends StatelessWidget {
  const FamilyScaffold({
    required this.title,
    required this.children,
    super.key,
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
      backgroundColor: AppColors.white,
      body: Column(
        children: [
          const PadTop(),
          AppBarRow(
            leading: RoundBtn(
              icon: backArrow(context),
              semanticLabel: s.strings.common.a11y_back,
              onTap: onBack ?? () => Navigator.pop(context),
            ),
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Typo.heading(ar: s.rtl).copyWith(fontSize: FontSizes.heading),
                ),
              ),
              if (trailing case final trailing?) trailing,
            ],
          ),
          if (bar case final bar?) bar,
          Expanded(
            child: ContentColumn(
              child: switch (onRefresh) {
                final onRefreshValue? => RefreshIndicator(
                    onRefresh: onRefreshValue,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 40),
                      children: children,
                    ),
                  ),
                _ => ListView(padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 40), children: children)
              },
            ),
          ),
          if (footer case final footer?)
            Container(
              padding: EdgeInsetsDirectional.fromSTEB(20, 12, 20, MediaQuery.paddingOf(context).bottom + 26),
              decoration: const BoxDecoration(
                color: AppColors.white,
                border: Border(top: BorderSide(color: AppColors.ink100)),
              ),
              child: ContentColumn(child: footer),
            ),
        ],
      ),
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
    required this.icon,
    required this.tone,
    required this.title,
    required this.sub,
    required this.onTap,
    super.key,
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
          // Canvas tile: 118 tall with the 14 padding, a 38px icon square
          // (radius 11), 10 to a 15/600 title, 2 to the 12px line.
          constraints: const BoxConstraints(minHeight: 90),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconSquare(icon, bg: t.bg, fg: t.ink, radius: AppRadii.iconSquare),
              const SizedBox(height: 10),
              Text(
                title,
                style: Typo.body(ar: s.rtl)
                    .copyWith(fontSize: FontSizes.bodyLg, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(sub, style: Typo.meta(ar: s.rtl)),
            ],
          ),
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
          const Icon(LucideIcons.lock, size: 13, color: AppColors.textTertiary),
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
  return Navigator.of(context, rootNavigator: true).push<R>(
    MaterialPageRoute(
      builder: (_) => Directionality(textDirection: s.dir, child: AdaptiveFrame(child: build(s))),
    ),
  );
}

/// The blood-type picker (`MC_BLOOD` chips plus "Not sure"): the eight ABO/Rh
/// types four to a row, read left to right in both languages, and "Not sure"
/// across the bottom. [onChanged] gets the type, or null for "Not sure".
/// Without [enabled] the choice shows but cannot change.
class BloodTypeGrid extends StatelessWidget {
  const BloodTypeGrid({
    required this.value,
    required this.unsure,
    required this.onChanged,
    super.key,
    this.enabled = true,
  });
  final BloodType? value;
  final bool unsure;
  final ValueChanged<BloodType?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final types = BloodType.values.where((b) => b != BloodType.bombay).toList();
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 8.0;
        final w = (c.maxWidth - gap * 3) / 4;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            ...types.map(
              (b) => SizedBox(
                width: w,
                child: _GridChip(
                  label: b.code.replaceAll('-', '−'),
                  ltr: true,
                  active: !unsure && value == b,
                  onTap: enabled ? () => onChanged(b) : null,
                ),
              ),
            ),
            SizedBox(
              width: c.maxWidth,
              child: _GridChip(
                label: s.strings.family.blood_unsure,
                active: unsure,
                onTap: enabled ? () => onChanged(null) : null,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A square-ish selectable chip for the blood-type grid.
class _GridChip extends StatelessWidget {
  const _GridChip({required this.label, required this.active, required this.onTap, this.ltr = false});
  final String label;
  final bool active;
  final VoidCallback? onTap;
  final bool ltr;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Semantics(
      button: true,
      selected: active,
      enabled: onTap != null,
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.fast,
          padding: const EdgeInsets.symmetric(vertical: 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? s.accent.main : AppColors.white,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(color: active ? s.accent.main : AppColors.border, width: 1.5),
          ),
          child: Text(
            label,
            textDirection: ltr ? TextDirection.ltr : null,
            style: (ltr ? Typo.num(weight: FontWeight.w700) : Typo.bodySm(ar: s.rtl)).copyWith(
              fontWeight: FontWeight.w600,
              color: active ? ColorContrast.onFill(s.accent.main) : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
