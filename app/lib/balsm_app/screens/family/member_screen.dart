import 'package:core/core.dart';
import 'package:family/family.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:medications/medications.dart';
import 'package:profile/profile.dart';
import 'package:records/records.dart';

import '../../app_state.dart';
import '../../kit.dart';
import '../../routes.dart';
import '../../tokens.dart';
import '../profile_subscreens.dart';
import '../records_screen.dart';
import 'add_member_screen.dart';
import 'family_kit.dart';
import 'member_card_screen.dart';
import 'profile_bar.dart';

/// Opens member [id]'s home (mother-child.jsx `MCMemberScreen`).
Future<void> openMember(BuildContext context, HealthProfileId id) =>
    pushFamilyScreen<void>(context, (_) => MemberScreen(id: id));

/// A member's own screen: their head and tiles, with edit and close in the
/// app bar menu. Leaves itself when the member is closed.
class MemberScreen extends ConsumerWidget {
  const MemberScreen({super.key, required this.id});
  final HealthProfileId id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final m =
        (ref.watch(familyMembersProvider).valueOrNull ?? const <FamilyMember>[]).where((x) => x.id == id).firstOrNull;
    if (m == null) return const Scaffold(backgroundColor: Colors.white);
    return FamilyScaffold(
      title: m.shortName,
      bar: const ProfileBar(),
      trailing: RoundBtn(
        icon: LucideIcons.moreVertical,
        semanticLabel: s.strings.family.member_menu,
        onTap: () => _showMemberMenu(context, ref, m),
      ),
      children: [MemberBody(member: m)],
    );
  }
}

/// Edit details · Medical details · Close profile.
Future<void> _showMemberMenu(BuildContext context, WidgetRef ref, FamilyMember m) {
  final s = AppScope.of(context);
  final f = s.strings.family;
  return showAppSheet<void>(
    context,
    textDirection: s.dir,
    builder: (ctx) => FamilySheet(title: m.displayName, children: [
      for (final (icon, label, danger, action) in [
        (LucideIcons.pencilLine, f.edit_details, false, () => openAddMember(context, editing: m)),
        (LucideIcons.clipboardList, f.edit_medical, false, () => openMemberMedical(context, m)),
        (LucideIcons.archive, f.close_profile, true, () => _confirmClose(context, ref, m)),
      ])
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: danger ? T.danger : T.fg2),
          title: Text(label, style: Typo.body(ar: s.rtl).copyWith(color: danger ? T.danger : T.fg1)),
          onTap: () {
            Navigator.pop(ctx);
            action();
          },
        ),
    ]),
  );
}

Future<void> _confirmClose(BuildContext context, WidgetRef ref, FamilyMember m) async {
  final s = AppScope.of(context);
  final f = s.strings.family;
  final yes = await showDialog<bool>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: s.dir,
      child: AlertDialog(
        title: Text(f.close_confirm_t(m.shortName)),
        content: Text(f.close_confirm_b),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.strings.common.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(f.close_profile, style: const TextStyle(color: T.danger)),
          ),
        ],
      ),
    ),
  );
  if (yes != true || !context.mounted) return;
  final result = await ref.read(closeFamilyMemberUseCaseProvider)(m.id, now: DateTime.now());
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  if (result.isSuccess) {
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(content: Text(f.closed_toast(m.shortName))));
  } else {
    messenger.showSnackBar(SnackBar(content: Text(f.save_failed(s.gender))));
  }
}

/// Medical details (blood type, conditions, allergies) of member [m] — the
/// app's medical-profile editor, pointed at the member's profile.
Future<void> openMemberMedical(BuildContext context, FamilyMember m) => pushFamilyScreen<void>(
      context,
      (s) => MedicalProfileScreen(s: s, profileId: m.id, title: m.displayName),
    );

/// The member's head and tiles (`MCMemberBody`), shared by the member screen
/// and Home while the member is the active profile.
class MemberBody extends ConsumerWidget {
  const MemberBody({super.key, required this.member});
  final FamilyMember member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final f = s.strings.family;
    final m = member;
    final now = DateTime.now();
    final health = ref.watch(memberHealthProfileProvider(m.id)).valueOrNull;
    final age = m.ageOn(now);
    final blood = (health?.bloodType ?? m.bloodType)?.code.replaceAll('-', '−');
    final allergies = health?.allergies.length ?? 0;
    // The tiles count the active profile's data; this member is the active
    // profile whenever their home is on screen (opening them selects them).
    final active = ref.watch(currentProfileIdProvider) == m.id;
    final meds = active ? (ref.watch(medicationListProvider).valueOrNull ?? const <Medication>[]).length : 0;
    final records = active ? (ref.watch(recordListProvider).valueOrNull ?? const <RecordDocument>[]).length : 0;
    final meta = [
      relationLabel(s, m.relationship, m.sex),
      if (age != null) ageLabel(s, age),
      if (m.dateOfBirth != null) f.born(formatDay(m.dateOfBirth!)),
    ].join(' · ');

    final tiles = <Widget>[
      FamilyTile(
        icon: LucideIcons.idCard,
        tone: MemberTone.blue,
        title: f.tile_card,
        sub: '${blood ?? '—'} · ${allergies == 0 ? f.no_allergies : f.allergies_n(allergies)}',
        onTap: () => openMemberCard(context, m.id),
      ),
      ..._childTiles(context, m, now),
      FamilyTile(
        icon: LucideIcons.pill,
        tone: MemberTone.blue,
        title: f.tile_meds,
        sub: meds == 0 ? f.no_meds : f.meds_n(meds),
        onTap: () => _openTab(context, ref, AppTab.meds),
      ),
      FamilyTile(
        icon: LucideIcons.folderHeart,
        tone: MemberTone.violet,
        title: f.tile_records,
        sub: records == 0 ? f.no_records : f.records_n(records),
        onTap: () => _openTab(context, ref, AppTab.records),
      ),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 20),
        child: Column(children: [
          MemberAvatar(m, size: 84),
          const SizedBox(height: 14),
          Text(m.displayName,
              textAlign: TextAlign.center, style: Typo.heading(ar: s.rtl).copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(meta, textAlign: TextAlign.center, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
          if (blood != null || (health?.conditions.isNotEmpty ?? false)) ...[
            const SizedBox(height: 10),
            Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: [
              if (blood != null) _Badge(blood, ltr: true),
              for (final c in health?.conditions ?? const <ChronicCondition>[]) _Badge(c.name),
            ]),
          ],
        ]),
      ),
      LayoutBuilder(builder: (context, c) {
        const gap = 10.0;
        final w = (c.maxWidth - gap) / 2;
        return Wrap(spacing: gap, runSpacing: gap, children: [for (final t in tiles) SizedBox(width: w, child: t)]);
      }),
    ]);
  }

  /// Tiles only a child gets — **stage 3 hook**. The design shows
  /// Vaccinations (`syringe`, emerald) and Growth (`ruler`, aqua) here, after
  /// the emergency card, for a member under 18 (`m.isChildOn(now)`). They
  /// render only once the vaccinations and growth modules exist; until then
  /// this adds nothing.
  List<Widget> _childTiles(BuildContext context, FamilyMember m, DateTime now) => const [];

  /// Medicines / Records: the member is already the active profile, so the
  /// app's own tabs show their data. Back to the tab bar first when this body
  /// sits on a pushed member screen.
  Future<void> _openTab(BuildContext context, WidgetRef ref, AppTab tab) async {
    final s = AppScope.of(context);
    await ref.read(activeProfileSwitcherProvider).select(member.id);
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
    s.setTab(tab);
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, {this.ltr = false});
  final String label;
  final bool ltr;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: T.neutralBg, borderRadius: BorderRadius.circular(T.rPill)),
      child: Text(
        label,
        textDirection: ltr ? TextDirection.ltr : null,
        style: (ltr ? Typo.num(size: FS.sm, weight: FontWeight.w700) : Typo.bodySm(ar: s.rtl))
            .copyWith(fontWeight: FontWeight.w600, color: T.fg2),
      ),
    );
  }
}
