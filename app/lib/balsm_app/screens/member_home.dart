import 'package:core/core.dart';
import 'package:family/family.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:medications/medications.dart';
import 'package:records/records.dart';
import 'package:self_report/self_report.dart';
import 'package:vaccinations/vaccinations.dart';

import '../app_state.dart';
import '../kit.dart';
import '../routes.dart';
import 'checkin_shared.dart';
import 'day_records_screen.dart';
import 'family/family_kit.dart';
import 'family/growth_screen.dart';
import 'family/member_card_screen.dart';
import 'family/member_medical_screen.dart';
import 'family/member_screen.dart';
import 'family/vaccinations_screen.dart';
import 'home_widgets.dart';
import 'profile_subscreens.dart' show memberHealthProfileProvider;
import 'quick_log.dart';
import 'records_screen.dart';
import 'report_flow.dart';
import 'trend_series.dart';
import 'trends_screen.dart';

/// Home's body while a family member is the active profile — home-mc.jsx
/// `HomeMemberV2`: the account holder's own Home layout, filled with the
/// member's data. In order: the check-in card ("How is Sara today?", logging
/// for them), their latest readings (a child's weight, height and pulse), six
/// shortcuts (emergency card, medical profile, records, medicines, then
/// trends and full profile — or vaccinations and growth for a child) and
/// their recent logs.
///
/// Every reading comes from the member's own profile ([profileCheckInsProvider]
/// keyed by their id), never from the account holder's. Medicines and records
/// are counted from the active-profile providers, which follow the switcher,
/// so they count only while this member is the active profile. Left out
/// against the account holder's Home: the travel banner, the onboarding
/// nudges, and the care-team / nearby-care shortcuts.
class MemberHomeBody extends ConsumerWidget {
  const MemberHomeBody({required this.member, required this.wide, super.key});
  final FamilyMember member;
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(profileCheckInsProvider(member.id)).value ?? const <CheckIn>[];
    final checkIn = _MemberCheckIn(member: member, history: history);
    final latest = _MemberLatest(member: member, history: history);
    final shortcuts = _MemberShortcuts(member: member, history: history, row: wide);
    final recent = _MemberRecent(member: member, history: history);
    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 115,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [checkIn, latest]),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 100,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [shortcuts, recent]),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        checkIn,
        latest,
        const SizedBox(height: 10),
        shortcuts,
        recent,
      ],
    );
  }
}

/// `.h2-checkin` for the member: today's state, the streak and the last
/// seven days from their own logs. The flow logs to the active profile,
/// which is this member.
class _MemberCheckIn extends StatelessWidget {
  const _MemberCheckIn({required this.member, required this.history});
  final FamilyMember member;
  final List<CheckIn> history;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final h = s.strings.home;
    final name = member.shortName;
    final child = member.isChildOn(DateTime.now());
    return HomeCheckInCard(
      done: todayCheckIn(history) != null,
      streak: checkInStreak(history),
      week: checkInDays(history, 7),
      question: h.member_ci_q(name),
      note: child ? h.member_ci_note_child(s.gender) : h.member_ci_note(s.gender, name),
      cta: h.member_ci_cta(s.gender, name),
      doneLabel: h.member_ci_done(name),
      showTime: false,
      // "Log for {name}" opens the full check-in for an adult member, worded
      // for them. A child gets Quick log instead: its child set (weight to
      // the growth log, no blood pressure or glucose) — the full check-in
      // asks for adult readings.
      onStart: () => child ? showQuickLog(context, source: ProductSource.home) : openCheckin(context),
      onReview: () => openMemberTrends(context, member),
    );
  }
}

/// `.h2-vitals` — the member's newest readings. A child shows weight (with
/// the day it was measured) and height from their growth log, then pulse,
/// oxygen and pain; anyone else blood pressure, glucose, oxygen, mood and
/// pain. Shown with dashes before anything is logged, as the design does.
class _MemberLatest extends ConsumerWidget {
  const _MemberLatest({required this.member, required this.history});
  final FamilyMember member;
  final List<CheckIn> history;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final r = LatestReadings.from(history);
    final pain = r.pain == null ? null : '${r.pain!.value}/10';
    final Widget card;
    if (member.isChildOn(DateTime.now())) {
      final growth = ref.watch(growthEntriesProvider(member.id)).value ?? const <GrowthEntry>[];
      final weighed = growth.where((g) => g.weightKg != null).firstOrNull;
      final measured = growth.where((g) => g.heightCm != null).firstOrNull;
      final pulse = history.map((c) => c.vitals.heartRate).nonNulls.firstOrNull;
      card = HomeVitalsCard.child(
        weight: weighed == null ? null : _num(weighed.weightKg!),
        weighedOn: weighed == null ? null : formatDay(weighed.measuredOn),
        height: measured == null ? null : _num(measured.heightCm!),
        pulse: pulse?.toString(),
        spo2: r.spo2?.toString(),
        pain: pain,
      );
    } else {
      final glucose = r.glucose;
      final hasBp = r.systolic != null && r.diastolic != null;
      card = HomeVitalsCard(
        bp: hasBp ? '${r.systolic}/${r.diastolic}' : null,
        bpHigh: hasBp && VitalLimits.bloodPressureElevated(r.systolic!, r.diastolic!),
        glucose: glucose?.toString(),
        glucoseHigh: glucose != null && VitalLimits.glucoseElevated(glucose, r.glucoseContext ?? GlucoseContext.random),
        spo2: r.spo2?.toString(),
        mood: switch (r.mood) { final mood? => moodLabel(s, mood.score), _ => null },
        pain: pain,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionHead(
          s.strings.checkin.latest,
          action: s.strings.common.see_all,
          onAction: () => openMemberTrends(context, member),
        ),
        card,
      ],
    );
  }

  /// 12.0 → "12", 3.45 → "3.45".
  static String _num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}

/// `.h2-shortcuts` — six tiles, three across: the member's emergency card
/// (blood type, allergies), medical profile (conditions), records,
/// medicines, then trends and their full profile — or, for a child,
/// vaccinations and growth.
class _MemberShortcuts extends ConsumerWidget {
  const _MemberShortcuts({required this.member, required this.history, required this.row});
  final FamilyMember member;
  final List<CheckIn> history;
  final bool row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final h = s.strings.home;
    final f = s.strings.family;
    final m = member;
    final now = DateTime.now();
    final child = m.isChildOn(now);
    final health = ref.watch(memberHealthProfileProvider(m.id)).value;
    final blood = (health?.bloodType ?? m.bloodType)?.code.replaceAll('-', '−');
    final allergies = health?.allergies.length ?? 0;
    final conditions = health?.conditions.length ?? 0;
    final growth = ref.watch(growthEntriesProvider(m.id)).value ?? const <GrowthEntry>[];
    // Medicines and records follow the active profile, which is this member
    // whenever their Home is on screen; zero in the moment a switch resolves.
    final active = ref.watch(currentProfileIdProvider) == m.id;
    final meds = active ? (ref.watch(medicationListProvider).value ?? const <Medication>[]).length : 0;
    final records = active ? (ref.watch(recordListProvider).value ?? const <RecordDocument>[]).length : 0;

    HomeShortcutTile tile(
      IconData icon,
      Color bg,
      Color fg,
      String label,
      int count,
      String unit,
      VoidCallback onTap, {
      String? value,
    }) =>
        HomeShortcutTile(
          icon: icon,
          iconBg: bg,
          iconFg: fg,
          label: label,
          count: count,
          value: value,
          unit: unit,
          onTap: onTap,
          row: row,
        );

    final List<HomeShortcutTile> last;
    if (child) {
      final vaccines = ref.watch(vaccinationsProvider(m.id)).value ?? const <VaccinationRecord>[];
      final next = VaccinationStatus.of(vaccines, today: now).next;
      last = [
        tile(
          LucideIcons.syringe,
          AppColors.hueEmerald50,
          AppColors.hueEmerald,
          s.strings.vacc.title,
          vaccines.length,
          next == null ? h.sc_recorded : h.sc_next(formatDay(next.nextDueOn!)),
          () => openVaccinations(context, m.id),
        ),
        tile(
          LucideIcons.ruler,
          AppColors.hueAqua50,
          AppColors.hueAqua,
          s.strings.growth.title,
          growth.length,
          h.sc_entries,
          () => openGrowth(context, m.id),
        ),
      ];
    } else {
      final trends = trendSeries(history, growth: growth).length;
      last = [
        tile(
          LucideIcons.trendingUp,
          AppColors.hueBlue50,
          AppColors.hueBlue,
          f.tile_trends,
          trends,
          h.sc_measures,
          () => openMemberTrends(context, m),
        ),
        tile(
          LucideIcons.user,
          AppColors.ink50,
          AppColors.textSecondary,
          h.sc_full_profile,
          0,
          relationLabel(s, m.relationship, m.sex),
          () => openMember(context, m.id),
          value: '',
        ),
      ];
    }
    final tiles = [
      tile(
        LucideIcons.idCard,
        AppColors.hueBlue50,
        AppColors.hueBlue,
        f.tile_card,
        0,
        allergies > 0 ? h.sc_allergies(allergies) : h.sc_blood,
        () => openMemberCard(context, m.id),
        value: blood ?? '—',
      ),
      tile(
        LucideIcons.clipboardList,
        AppColors.hueMint50,
        AppColors.hueMint600,
        f.tile_medical,
        conditions,
        h.sc_conditions,
        () => openMemberMedical(context, m),
      ),
      tile(
        LucideIcons.folderHeart,
        AppColors.hueViolet50,
        AppColors.hueViolet,
        h.sc_records,
        records,
        s.strings.records.rec_documents,
        () => s.setTab(AppTab.records),
      ),
      tile(
        LucideIcons.pill,
        AppColors.hueBlue50,
        AppColors.hueBlue,
        f.tile_meds,
        meds,
        h.sc_meds,
        () => s.setTab(AppTab.meds),
      ),
      ...last,
    ];
    if (row) {
      return Column(
        children: [
          ...tiles.indexed.map(
            (e) => Padding(
              padding: EdgeInsetsDirectional.only(top: e.$1 == 0 ? 0 : 8),
              child: e.$2,
            ),
          ),
        ],
      );
    }
    Widget line(List<HomeShortcutTile> three) => IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...three.indexed.map(
                (e) => Expanded(
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(start: e.$1 == 0 ? 0 : 8),
                    child: e.$2,
                  ),
                ),
              ),
            ],
          ),
        );
    return Column(
      children: [
        line(tiles.sublist(0, 3)),
        const SizedBox(height: 8),
        line(tiles.sublist(3)),
      ],
    );
  }
}

/// `.h2-recent` — the member's last three days with logs; each opens that
/// day. With nothing logged it says so, naming them.
class _MemberRecent extends StatelessWidget {
  const _MemberRecent({required this.member, required this.history});
  final FamilyMember member;
  final List<CheckIn> history;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final recent = groupCheckInsByDay(history).take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionHead(
          s.strings.common.recent,
          action: recent.isEmpty ? null : s.strings.common.see_all,
          onAction: recent.isEmpty ? null : () => openMemberTrends(context, member),
        ),
        PCard(
          padding: EdgeInsets.zero,
          child: recent.isEmpty
              ? Padding(
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 18),
                  child: Text(
                    s.strings.home.member_recent_empty(member.shortName),
                    textAlign: TextAlign.center,
                    style: Typo.meta(ar: s.rtl),
                  ),
                )
              : Column(
                  children: recent.indexed
                      .map(
                        (e) => CheckInDayRow(
                          day: e.$2,
                          first: e.$1 == 0,
                          onTap: () => DayRecordsScreen.open(context, e.$2),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }
}
