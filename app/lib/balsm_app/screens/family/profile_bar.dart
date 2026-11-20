import 'package:core/core.dart';
import 'package:family/family.dart';
import 'package:family_link/family_link.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app_state.dart';
import '../../flags.dart';
import '../../kit.dart';
import '../../tokens.dart';
import 'family_kit.dart';
import 'family_screen.dart';

/// Active-profile bar (`Mother and Child.dc.html`, the canvas matched to the
/// shipped app; mother-child.jsx `MCProfileBar`): under the Home header and on
/// the Meds and Records tabs, so it is always clear whose data is on screen.
/// A soft pill — no border — with a 28px avatar, "Viewing <whose>" and
/// "Change ⌄". Tapping it opens the people picker.
class ProfileBar extends ConsumerWidget {
  const ProfileBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final f = s.strings.family;
    final m = ref.watch(activeFamilyMemberProvider);
    final tone = m == null ? null : toneColors(m.tone);
    // A link request waiting for this account's answer (pulled — no push).
    final waiting =
        familyLinkOn(s.flags) && (ref.watch(familyLinksProvider).valueOrNull?.awaitingMe.isNotEmpty ?? false);
    final avatar = m == null ? const SelfAvatar(size: 28) : MemberAvatar(m, size: 28);
    return Semantics(
      button: true,
      label: waiting ? '${f.bar_a11y}. ${f.link_dot_a11y}' : f.bar_a11y,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: Pressable(
          onTap: () => showProfilePicker(context),
          scale: 0.99,
          child: Container(
            padding: const EdgeInsetsDirectional.fromSTEB(5, 5, 12, 5),
            decoration: BoxDecoration(
              color: tone?.bg ?? T.ink50,
              borderRadius: BorderRadius.circular(T.rPill),
            ),
            child: Row(children: [
              if (!waiting)
                avatar
              else
                Stack(clipBehavior: Clip.none, children: [
                  avatar,
                  PositionedDirectional(
                    top: -2,
                    end: -2,
                    child: Container(
                      key: const ValueKey('family-link-dot'),
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: T.danger,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ]),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '${f.bar_viewing(s.gender)} '),
                    TextSpan(
                      text: m == null
                          ? f.bar_your_profile
                          : '${m.shortName} · ${relationLabel(s, m.relationship, m.sex)}',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: T.fg1),
                    ),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg2),
                ),
              ),
              const SizedBox(width: 8),
              Text(f.bar_change,
                  style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: tone?.ink ?? s.accent.d)),
              const SizedBox(width: 2),
              Icon(LucideIcons.chevronDown, size: 16, color: tone?.ink ?? s.accent.d),
            ]),
          ),
        ),
      ),
    );
  }
}

/// People picker (`MCPickerSheet`) — lists people, never accounts. Choosing
/// one re-points the active profile, so every profile-scoped screen follows.
Future<void> showProfilePicker(BuildContext context) {
  final s = AppScope.of(context);
  return showAppSheet<void>(context, textDirection: s.dir, builder: (_) => const _PickerSheet());
}

class _PickerSheet extends ConsumerWidget {
  const _PickerSheet();

  Future<void> _pick(BuildContext context, WidgetRef ref, HealthProfileId? id) async {
    final switcher = ref.read(activeProfileSwitcherProvider);
    Navigator.pop(context);
    if (id == null) {
      await switcher.selectSelf();
    } else {
      await switcher.select(id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final f = s.strings.family;
    final active = ref.watch(activeFamilyMemberProvider);
    final sections = ref.watch(familySectionsProvider) ?? const [];
    final name = (ref.watch(accountSummaryProvider).valueOrNull?.displayName ?? '').trim();
    final now = DateTime.now();
    return FamilySheet(
      title: f.picker_title(s.gender),
      sub: f.picker_sub(s.gender),
      children: [
        _card([
          _PickRow(
            avatar: const SelfAvatar(size: 40),
            name: name,
            sub: f.picker_you(s.gender),
            on: active == null,
            onTap: () => _pick(context, ref, null),
          ),
        ]),
        for (final section in sections) ...[
          GroupHead(label: groupLabel(s, section.group), count: section.members.length),
          _card([
            for (final m in section.members)
              _PickRow(
                avatar: MemberAvatar(m, size: 40),
                name: m.displayName,
                sub: memberSubtitle(s, m, now),
                on: active?.id == m.id,
                onTap: () => _pick(context, ref, m.id),
              ),
          ]),
        ],
        const SizedBox(height: 14),
        PButton(
          f.manage_family,
          icon: LucideIcons.users,
          variant: BtnVariant.secondary,
          large: true,
          block: true,
          ar: s.rtl,
          onTap: () {
            Navigator.pop(context);
            openFamily(context);
          },
        ),
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(LucideIcons.repeat, size: 15, color: T.fg3),
          ),
          const SizedBox(width: 9),
          Expanded(child: Text(f.picker_note(s.gender), style: Typo.meta(ar: s.rtl).copyWith(height: 1.5))),
        ]),
      ],
    );
  }

  Widget _card(List<Widget> rows) => PCard(
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(T.rLg),
          child: Column(children: rows),
        ),
      );
}

class _PickRow extends StatelessWidget {
  const _PickRow({required this.avatar, required this.name, required this.sub, required this.on, required this.onTap});
  final Widget avatar;
  final String name;
  final String sub;
  final bool on;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Semantics(
      selected: on,
      button: true,
      child: PressHighlight(
        onTap: onTap,
        child: Container(
          color: on ? s.accent.bg : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            avatar,
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (name.isNotEmpty)
                  Text(name, style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
                Text(sub, style: Typo.meta(ar: s.rtl)),
              ]),
            ),
            if (on) Icon(LucideIcons.checkCircle2, size: 22, color: s.accent.main),
          ]),
        ),
      ),
    );
  }
}
