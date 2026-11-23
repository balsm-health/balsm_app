import 'dart:async';
import 'package:core/core.dart';
import 'package:family/family.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:medications/medications.dart';
import 'package:pregnancy/pregnancy.dart';
import 'package:profile/profile.dart';
import 'package:records/records.dart';
import 'package:self_report/self_report.dart';
import 'package:vaccinations/vaccinations.dart';

import '../../app_state.dart';
import '../../kit.dart';
import '../../routes.dart';
import '../pregnancy/pregnancy_kit.dart' show dueLine;
import '../pregnancy/pregnancy_screen.dart';
import '../profile_subscreens.dart' show memberHealthProfileProvider;
import '../records_screen.dart';
import '../trend_series.dart';
import '../trends_screen.dart';
import 'add_member_screen.dart';
import 'family_kit.dart';
import 'growth_screen.dart';
import 'member_card_screen.dart';
import 'member_medical_screen.dart';
import 'profile_bar.dart';
import 'vaccinations_screen.dart';

/// Opens member [id]'s home (mother-child.jsx `MCMemberScreen`).
Future<void> openMember(BuildContext context, HealthProfileId id) =>
    pushFamilyScreen<void>(context, (_) => MemberScreen(id: id));

/// A member's own screen: their head and tiles, with edit and close in the
/// app bar menu. Leaves itself when the member is closed.
class MemberScreen extends ConsumerWidget {
  const MemberScreen({required this.id, super.key});
  final HealthProfileId id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    // The screen is the active member's: choosing someone else in the bar's
    // picker left it showing this member under "Viewing your profile", with
    // tiles counting the other person's data. It closes instead.
    ref.listen<HealthProfileId?>(currentProfileIdProvider, (previous, next) {
      if (previous == id && next != null && next != id) Navigator.maybePop(context);
    });
    final m = (ref.watch(familyMembersProvider).value ?? const <FamilyMember>[]).where((x) => x.id == id).firstOrNull;
    if (m == null) return const Scaffold(backgroundColor: AppColors.white);
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
    builder: (ctx) => FamilySheet(
      title: m.displayName,
      children: [
        for (final (icon, label, danger, action) in [
          (LucideIcons.pencilLine, f.edit_details, false, () => _editDetails(context, m)),
          (LucideIcons.clipboardList, f.edit_medical, false, () => openMemberMedical(context, m)),
          (LucideIcons.archive, f.close_profile, true, () => _confirmClose(context, ref, m)),
        ])
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(icon, color: danger ? AppColors.danger : AppColors.textSecondary),
            title: Text(
              label,
              style: Typo.body(ar: s.rtl).copyWith(color: danger ? AppColors.danger : AppColors.textPrimary),
            ),
            onTap: () {
              Navigator.pop(ctx);
              unawaited(action());
            },
          ),
      ],
    ),
  );
}

Future<void> _confirmClose(BuildContext context, WidgetRef ref, FamilyMember m) async {
  if (await confirmCloseMember(context, ref, m) && context.mounted) Navigator.pop(context);
}

/// Edits [m]'s details; leaves the member's screen too when the edit screen
/// closed the profile.
Future<void> _editDetails(BuildContext context, FamilyMember m) async {
  final closed = await openAddMember(context, editing: m);
  if (closed && context.mounted) Navigator.pop(context);
}

/// The member's head and tiles (`MCMemberBody`), shared by the member screen
/// and Home while the member is the active profile.
class MemberBody extends ConsumerWidget {
  const MemberBody({required this.member, super.key});
  final FamilyMember member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final f = s.strings.family;
    final m = member;
    final now = DateTime.now();
    final health = ref.watch(memberHealthProfileProvider(m.id)).value;
    final age = m.ageOn(now);
    final blood = (health?.bloodType ?? m.bloodType)?.code.replaceAll('-', '−');
    final allergies = health?.allergies.length ?? 0;
    final conditions = health?.conditions.length ?? 0;
    final preg = ref.watch(activePregnancyOfProvider(m.id));
    final trends = trendSeries(
      ref.watch(profileCheckInsProvider(m.id)).value ?? const <CheckIn>[],
      growth: ref.watch(growthEntriesProvider(m.id)).value ?? const <GrowthEntry>[],
    ).length;
    // The tiles count the active profile's data; this member is the active
    // profile whenever their home is on screen (opening them selects them).
    final active = ref.watch(currentProfileIdProvider) == m.id;
    final meds = active ? (ref.watch(medicationListProvider).value ?? const <Medication>[]).length : 0;
    final records = active ? (ref.watch(recordListProvider).value ?? const <RecordDocument>[]).length : 0;
    final meta = [
      relationLabel(s, m.relationship, m.sex),
      if (age != null) ageLabel(s, age),
      if (m.dateOfBirth case final dateOfBirth?) f.born(formatDay(dateOfBirth)),
    ].join(' · ');

    final tiles = <Widget>[
      FamilyTile(
        icon: LucideIcons.idCard,
        tone: MemberTone.blue,
        title: f.tile_card,
        // "O+ · 1 allergy" (canvas); no dash in front while no blood type is set.
        sub: [if (blood != null) blood, if (allergies == 0) f.no_allergies else f.allergies_n(allergies)].join(' · '),
        onTap: () => openMemberCard(context, m.id),
      ),
      ..._childTiles(context, ref, m, now),
      FamilyTile(
        icon: LucideIcons.folderHeart,
        tone: MemberTone.violet,
        title: f.tile_records,
        sub: records == 0 ? f.no_records : f.records_n(records),
        onTap: () => _openTab(context, ref, AppTab.records),
      ),
      if (preg != null || m.canTrackPregnancyOn(now))
        FamilyTile(
          icon: LucideIcons.sprout,
          tone: MemberTone.aqua,
          title: s.strings.pregnancy.title,
          sub: preg == null
              ? f.tile_preg_off(s.gender)
              : '${s.strings.pregnancy.week_n(preg.infoOn(now).week)} · ${dueLine(s, preg.infoOn(now))}',
          onTap: () => openPregnancy(context, ref, mother: m.id),
        ),
      FamilyTile(
        icon: LucideIcons.clipboardList,
        tone: MemberTone.emerald,
        title: f.tile_medical,
        sub: [
          blood ?? f.no_blood,
          if (allergies > 0) f.allergies_n(allergies),
          if (conditions > 0) f.conditions_n(conditions),
        ].join(' · '),
        onTap: () => openMemberMedical(context, m),
      ),
      FamilyTile(
        icon: LucideIcons.trendingUp,
        tone: MemberTone.blue,
        title: f.tile_trends,
        sub: trends == 0 ? f.trends_none : f.trends_n(trends),
        onTap: () => openMemberTrends(context, m),
      ),
      FamilyTile(
        icon: LucideIcons.pill,
        tone: MemberTone.blue,
        title: f.tile_meds,
        sub: meds == 0 ? f.no_meds : f.meds_n(meds),
        onTap: () => _openTab(context, ref, AppTab.meds),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          // Canvas "06 Member profile": 8 above, 84px avatar, 12 to the 26/800
          // name, 6 to the meta, 10 to the chips, 16 to the tiles.
          padding: const EdgeInsetsDirectional.only(top: 8, bottom: 16),
          child: Column(
            children: [
              MemberAvatar(m, size: 84),
              const SizedBox(height: 12),
              Text(
                m.displayName,
                textAlign: TextAlign.center,
                style: Typo.title(ar: s.rtl).copyWith(fontWeight: FontWeight.w800, height: 1.3),
              ),
              const SizedBox(height: 6),
              Text(
                meta,
                textAlign: TextAlign.center,
                style: Typo.bodySm(ar: s.rtl).copyWith(color: AppColors.textTertiary),
              ),
              if (blood != null || (health?.conditions.isNotEmpty ?? false)) ...[
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (blood != null) _Badge(blood, ltr: true),
                    for (final c in health?.conditions ?? const <ChronicCondition>[]) _Badge(c.name),
                  ],
                ),
              ],
            ],
          ),
        ),
        LayoutBuilder(
          builder: (context, c) {
            const gap = 10.0;
            final w = (c.maxWidth - gap) / 2;
            return Wrap(spacing: gap, runSpacing: gap, children: [for (final t in tiles) SizedBox(width: w, child: t)]);
          },
        ),
      ],
    );
  }

  /// Tiles only a child gets (`m.isChildOn(now)`), after the emergency
  /// card: Vaccinations — the next dose due, else how many are recorded —
  /// and Growth — the day of the latest entry. Both read member [m]'s own
  /// log, whichever profile is active.
  List<Widget> _childTiles(BuildContext context, WidgetRef ref, FamilyMember m, DateTime now) {
    if (!m.isChildOn(now)) return const [];
    final s = AppScope.of(context);
    final vaccines = ref.watch(vaccinationsProvider(m.id)).value ?? const <VaccinationRecord>[];
    final next = VaccinationStatus.of(vaccines, today: now).next;
    final growth = ref.watch(growthEntriesProvider(m.id)).value ?? const <GrowthEntry>[];
    return [
      FamilyTile(
        icon: LucideIcons.syringe,
        tone: MemberTone.emerald,
        title: s.strings.vacc.title,
        sub: next == null
            ? s.strings.vacc.recorded_n(vaccines.length)
            : s.strings.vacc.tile_next(formatDay(next.nextDueOn!)),
        onTap: () => openVaccinations(context, m.id),
      ),
      FamilyTile(
        icon: LucideIcons.ruler,
        tone: MemberTone.aqua,
        title: s.strings.growth.title,
        sub: growth.isEmpty
            ? s.strings.growth.tile_empty
            : s.strings.growth.tile_last(formatDay(growth.first.measuredOn)),
        onTap: () => openGrowth(context, m.id),
      ),
    ];
  }

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
    // Canvas chip: 26 high, 10 either side; the blood type bold in the
    // display face, a condition in regular body text.
    return Container(
      height: 26,
      alignment: Alignment.center,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: AppColors.neutralBackground, borderRadius: BorderRadius.circular(AppRadii.pill)),
      child: Text(
        label,
        textDirection: ltr ? TextDirection.ltr : null,
        style: ltr
            ? Typo.num(size: FontSizes.meta, weight: FontWeight.w700)
            : Typo.meta(ar: s.rtl).copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}
