import 'package:core/core.dart';
import 'package:family/family.dart';
import 'package:family_link/family_link.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app_state.dart';
import '../../assets.dart';
import '../../family/family_links_sync.dart';
import '../../flags.dart';
import '../../kit.dart';
import '../../tokens.dart';
import 'add_member_screen.dart';
import 'family_kit.dart';
import 'family_link_rows.dart';
import 'link_scan_screen.dart';
import 'member_card_screen.dart';
import 'member_screen.dart';
import 'profile_bar.dart';

/// Opens the Family screen (mother-child.jsx `MCFamilyScreen`).
Future<void> openFamily(BuildContext context) => pushFamilyScreen<void>(context, (_) => const FamilyScreen());

/// Family — the member profiles this phone manages, grouped, with each
/// one's emergency card a tap away. Opening a member makes them the active
/// profile, as the design does.
///
/// With family links on it also lists link requests waiting for this
/// account's answer and the accounts it is linked with or waiting on, pulled
/// when the screen opens and on pull-to-refresh.
class FamilyScreen extends ConsumerStatefulWidget {
  const FamilyScreen({super.key});
  @override
  ConsumerState<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends ConsumerState<FamilyScreen> {
  bool get _links => familyLinkOn(AppScope.of(context).flags);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _links) pullFamilyLinks(ref);
    });
  }

  Future<void> _open(BuildContext context, WidgetRef ref, FamilyMember m, {bool card = false}) async {
    await ref.read(activeProfileSwitcherProvider).select(m.id);
    if (!context.mounted) return;
    if (card) {
      await openMemberCard(context, m.id);
    } else {
      await openMember(context, m.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final f = s.strings.family;
    final sections = ref.watch(familySectionsProvider);
    final links = _links;
    final now = DateTime.now();
    return FamilyScaffold(
      title: f.title,
      bar: const ProfileBar(),
      onRefresh: links ? () => ref.read(familyLinksProvider.notifier).refresh() : null,
      footer: PButton(
        f.add_member,
        icon: LucideIcons.userPlus,
        large: true,
        block: true,
        accent: s.accent,
        ar: s.rtl,
        onTap: () => showAddMemberSheet(context),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(f.intro(s.gender), style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg2)),
        ),
        if (links) const FamilyLinkSections(),
        if (sections == null)
          const SizedBox.shrink()
        else if (sections.isEmpty)
          const _Empty()
        else
          for (final section in sections) ...[
            GroupHead(label: groupLabel(s, section.group), count: section.members.length),
            PCard(
              padding: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(T.rLg),
                child: Column(children: [
                  for (final (i, m) in section.members.indexed)
                    _MemberRow(
                      member: m,
                      sub: memberSubtitle(s, m, now),
                      divider: i > 0,
                      onTap: () => _open(context, ref, m),
                      onCard: () => _open(context, ref, m, card: true),
                    ),
                ]),
              ),
            ),
          ],
        const StaysLocalNote(),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final f = s.strings.family;
    return PCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Column(children: [
        Opacity(opacity: 0.9, child: SvgPicture.asset(Assets.brand_icon, width: 44, height: 44)),
        const SizedBox(height: 10),
        Text(f.empty_t,
            textAlign: TextAlign.center,
            style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg1)),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: Text(f.empty_b(s.gender),
              textAlign: TextAlign.center, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg2)),
        ),
      ]),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.sub,
    required this.divider,
    required this.onTap,
    required this.onCard,
  });
  final FamilyMember member;
  final String sub;
  final bool divider;
  final VoidCallback onTap;
  final VoidCallback onCard;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return PressHighlight(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 10, 12),
        decoration: divider ? const BoxDecoration(border: Border(top: BorderSide(color: T.ink100))) : null,
        child: Row(children: [
          MemberAvatar(member, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(member.displayName, style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
              Text(sub, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
            ]),
          ),
          RoundBtn(icon: LucideIcons.idCard, semanticLabel: s.strings.family.tile_card, onTap: onCard),
          const SizedBox(width: 4),
          Chevron(rtl: s.rtl),
        ]),
      ),
    );
  }
}

/// "Add family member" (`MCAddSheet`): enter a member's details by hand, or
/// — with family links on — scan the profile QR of someone with their own
/// Balsm account, who then approves the request in their app.
Future<void> showAddMemberSheet(BuildContext context) {
  final s = AppScope.of(context);
  return showAppSheet<void>(
    context,
    textDirection: s.dir,
    builder: (ctx) {
      final f = s.strings.family;
      return FamilySheet(title: f.add_member, children: [
        _AddRow(
          icon: LucideIcons.pencilLine,
          accent: true,
          title: f.manual_t,
          sub: f.manual_b(s.gender),
          onTap: () {
            Navigator.pop(ctx);
            openAddMember(context);
          },
        ),
        if (familyLinkOn(s.flags)) ...[
          const SizedBox(height: 10),
          _AddRow(
            icon: LucideIcons.qrCode,
            title: f.scan_t,
            sub: f.scan_b,
            onTap: () {
              Navigator.pop(ctx);
              openLinkScan(context);
            },
          ),
        ],
        const StaysLocalNote(center: false),
      ]);
    },
  );
}

/// `MCAddRow` — icon square, title, one line under it, chevron.
class _AddRow extends StatelessWidget {
  const _AddRow({required this.icon, required this.title, required this.sub, required this.onTap, this.accent = false});
  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;
  final bool accent;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return PressHighlight(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(T.rLg), border: Border.all(color: T.border)),
        child: Row(children: [
          IconSquare(icon,
              bg: accent ? s.accent.bg : T.ink50, fg: accent ? s.accent.main : T.fg2, size: 44, iconSize: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg1)),
              const SizedBox(height: 2),
              Text(sub, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
            ]),
          ),
          Chevron(rtl: s.rtl),
        ]),
      ),
    );
  }
}
