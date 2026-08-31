import 'package:core/core.dart' show accountSummaryProvider, currentUserIdProvider;
import 'package:emergency_card/emergency_card.dart' show EmergencyCardSnapshot, emergencySnapshotReaderProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:medications/medications.dart' show DoseOutcome, TodayDose, medicationListProvider, todayDosesProvider;
import 'package:records/records.dart';
import 'package:self_report/self_report.dart';
import 'home_widgets.dart';
import 'records_screen.dart';
import '../app_state.dart';
import '../kit.dart';
import '../responsive.dart';
import '../tokens.dart';
import '../widgets/account_switcher.dart';
import 'checkin_shared.dart';
import 'personal_details.dart';
import 'profile_subscreens.dart';

/// Home tab — P001 patient-MVP scope.
///
/// Ported onto real providers: the greeting name comes from the account
/// summary (not the sample family-account data), and the status cards reflect
/// real on-device state — onboarding nudges (claim handle, set up the
/// emergency card, add a first medication) plus a today's-medications summary.
/// Every card is driven by real on-device state and hides itself when it has
/// nothing to say — no streak at zero, no metric grid before the first
/// check-in, no appointment strip with nothing booked. Signed-out-safe: every
/// real read resolves to an empty/hidden state rather than crashing.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    // Real account summary → greeting name. Null while loading / signed out;
    // the greeting label still renders, just without a name.
    final summary = ref.watch(accountSummaryProvider).valueOrNull;
    final displayName = (summary?.displayName ?? '').trim();
    final firstName = displayName.split(' ').first;

    return ContentColumn(
      maxWidth: 720,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const PadTop(),

          // App bar: avatar (account switcher) + greeting + bell.
          AppBarRow(children: [
            _AvatarButton(initials: accountInitials(displayName), onTap: () => showAccountSwitcher(context)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.strings.home.greet, style: Typo.meta(ar: s.rtl)),
                if (firstName.isNotEmpty) Text(firstName, style: Typo.heading(ar: s.rtl).copyWith(fontSize: FS.xl)),
              ]),
            ),
            RoundBtn(icon: LucideIcons.bell, onTap: () {}),
          ]),

          // Daily check-in hero — the primary action on this screen.
          const _CheckInSection(),

          // Next scheduled visit; hides itself when nothing is booked.
          const UpcomingAppointmentStrip(),

          // Onboarding nudges — driven by real P001 providers (handle /
          // emergency card / first medication). Each stays hidden until its
          // provider resolves, so signed-out never flashes a wrong nudge.
          const _NudgeSection(),

          // Nearby care + records shortcuts.
          HomeShortcut(
            icon: LucideIcons.mapPin,
            iconBg: T.petalBlue50,
            iconFg: T.petalBlue,
            title: s.strings.care.map_nearby,
            subtitle: s.strings.care.map_sub,
            onTap: () => s.setTab('map'),
          ),
          const _RecordsShortcut(),

          // Latest readings — only once something has been logged.
          const _LatestMetrics(),

          // Today's medications — real on-device schedule.
          const _TodayMedsCard(),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// On-device emergency-card snapshot for the home nudge. Same seam the
/// emergency/personal-details port uses; `null` when signed out or before a
/// profile exists.
final _homeEmergencySnapshotProvider = FutureProvider.autoDispose<EmergencyCardSnapshot?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return ref.watch(emergencySnapshotReaderProvider).readSnapshot();
});

/// Onboarding nudge cards, gated by real state.
class _NudgeSection extends ConsumerWidget {
  const _NudgeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);

    // Handle: hide once the account summary carries one.
    final summaryAsync = ref.watch(accountSummaryProvider);
    final needsHandle = summaryAsync.hasValue && summaryAsync.valueOrNull?.handle == null;

    // Emergency card: nudge until the on-device snapshot has any data.
    final snapshotAsync = ref.watch(_homeEmergencySnapshotProvider);
    final snapshot = snapshotAsync.valueOrNull;
    final needsEmergencyCard = snapshotAsync.hasValue && (snapshot == null || !snapshot.hasAnyData);

    // First medication: nudge while the med list is empty.
    final medsAsync = ref.watch(medicationListProvider);
    final needsFirstMedication = medsAsync.hasValue && (medsAsync.valueOrNull?.isEmpty ?? false);

    return Column(children: [
      if (needsHandle)
        _Shortcut(
          icon: LucideIcons.atSign,
          iconBg: T.petalMint50,
          iconFg: T.petalMint,
          title: s.strings.home.nudge_handle,
          subtitle: s.strings.home.nudge_handle_sub,
          onTap: () => openPersonalDetails(context),
        ),
      if (needsEmergencyCard)
        _Shortcut(
          icon: LucideIcons.shieldAlert,
          iconBg: T.petalAqua50,
          iconFg: T.petalAqua,
          title: s.strings.home.nudge_ec,
          subtitle: s.strings.home.nudge_ec_sub,
          onTap: () => openEmergency(context),
        ),
      if (needsFirstMedication)
        _Shortcut(
          icon: LucideIcons.pill,
          iconBg: T.petalViolet50,
          iconFg: T.petalViolet,
          title: s.strings.home.nudge_med,
          subtitle: s.strings.home.nudge_med_sub,
          onTap: () => s.setTab('meds'),
        ),
    ]);
  }
}

/// Today's medications summary — real `todayDosesProvider`. Hidden when there
/// are no doses scheduled today (or signed out). Taking a dose happens on the
/// medications tab; the row's action routes there.
class _TodayMedsCard extends ConsumerWidget {
  const _TodayMedsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final doses = ref.watch(todayDosesProvider).valueOrNull ?? const <TodayDose>[];
    if (doses.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      RowHead(s.strings.meds.meds_today, action: s.strings.common.see_all, onAction: () => s.setTab('meds'), ar: s.rtl),
      PCard(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(children: doses.indexed.map((e) => _HomeDoseRow(dose: e.$2, first: e.$1 == 0)).toList()),
      ),
    ]);
  }
}

class _HomeDoseRow extends StatelessWidget {
  const _HomeDoseRow({required this.dose, required this.first});
  final TodayDose dose;
  final bool first;

  static String _hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final med = dose.medication;
    final taken = dose.event?.outcome == DoseOutcome.taken;
    final subtitle = [
      if (med.doseAmount != null && med.doseAmount!.isNotEmpty) med.doseAmount!,
      _hm(dose.scheduledAt),
    ].join(' · ');
    return Container(
      decoration: BoxDecoration(border: first ? null : const Border(top: BorderSide(color: T.ink100))),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(children: [
        Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: s.accent.bg, borderRadius: BorderRadius.circular(T.rMd)),
            child: Icon(LucideIcons.pill, size: 21, color: s.accent.d)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(med.name, style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
            Text(subtitle, textDirection: TextDirection.ltr, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
          ]),
        ),
        if (taken)
          Pill(s.strings.meds.taken, kind: PillKind.success, ar: s.rtl)
        else
          PButton(s.strings.meds.take,
              variant: BtnVariant.soft, accent: s.accent, ar: s.rtl, onTap: () => s.setTab('meds')),
      ]),
    );
  }
}

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({required this.initials, required this.onTap});
  final String initials;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    // P001 is single-account, so no multi-account badge dot. Initials come from
    // the real account summary; empty while loading / signed out.
    return Pressable(
      onTap: onTap,
      scale: 0.95,
      child: Avatar(initials: initials, color: T.petalAqua, ar: s.rtl),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut(
      {required this.icon,
      required this.iconBg,
      required this.iconFg,
      required this.title,
      required this.subtitle,
      required this.onTap});
  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return PCard(
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      onTap: onTap,
      child: Row(children: [
        IconSquare(icon, bg: iconBg, fg: iconFg),
        const SizedBox(width: 13),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
            const SizedBox(height: 1),
            Text(subtitle, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
          ]),
        ),
        Chevron(rtl: s.rtl),
      ]),
    );
  }
}

/// Check-in hero + streak, both driven by real check-in history.
class _CheckInSection extends ConsumerWidget {
  const _CheckInSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final history = ref.watch(checkInHistoryProvider).valueOrNull ?? const <CheckIn>[];
    final done = todayCheckIn(history) != null;
    final streak = checkInStreak(history);
    return Column(children: [
      HomeHero(
        done: done,
        onStart: () => s.setTab('checkin'),
        onReview: () => s.setTab('trends'),
      ),
      // A streak of zero is not an achievement worth a card.
      if (streak > 0) HomeStreak(days: streak),
    ]);
  }
}

/// Records shortcut, with a live document count.
class _RecordsShortcut extends ConsumerWidget {
  const _RecordsShortcut();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final count = (ref.watch(recordListProvider).valueOrNull ?? const <RecordDocument>[]).length;
    return HomeShortcut(
      icon: LucideIcons.folderHeart,
      iconBg: T.petalViolet50,
      iconFg: T.petalViolet,
      title: s.strings.records.records,
      subtitle: '$count ${s.strings.records.rec_documents}',
      onTap: () => s.setTab('records'),
    );
  }
}

/// `.metric-grid` — the most recent reading of each tracked vital. Hidden
/// until at least one check-in exists, so a new patient sees no empty tiles.
class _LatestMetrics extends ConsumerWidget {
  const _LatestMetrics();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final history = ref.watch(checkInHistoryProvider).valueOrNull ?? const <CheckIn>[];
    if (history.isEmpty) return const SizedBox.shrink();
    final latest = history.first;
    final v = latest.vitals;
    final glucose = v.glucoseFasting ?? v.glucosePostMeal ?? v.glucoseRandom;

    final tiles = <Widget>[
      if (v.systolic != null && v.diastolic != null)
        MetricTile(
          icon: LucideIcons.activity,
          label: s.strings.profile.m_bp,
          value: '${v.systolic}/${v.diastolic}',
          unit: s.strings.checkin.unit_bp,
        ),
      if (glucose != null)
        MetricTile(
          icon: LucideIcons.droplet,
          label: s.strings.profile.m_glucose,
          value: '$glucose',
          unit: s.strings.checkin.unit_glu,
        ),
      if (latest.mood != null)
        MetricTile(
          icon: LucideIcons.smile,
          label: s.strings.profile.m_mood,
          value: moodLabel(s, latest.mood!.score),
        ),
      MetricTile(
        icon: LucideIcons.thermometer,
        label: s.strings.profile.m_pain,
        value: '${latest.painLevel.value}/10',
      ),
    ];
    if (tiles.isEmpty) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      RowHead(s.strings.checkin.latest, ar: s.rtl),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.72,
          children: tiles,
        ),
      ),
    ]);
  }
}
