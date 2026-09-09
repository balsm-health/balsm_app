import 'package:core/core.dart' show accountSummaryProvider, currentUserIdProvider;
import 'package:emergency_card/emergency_card.dart' show EmergencyCardSnapshot, emergencySnapshotReaderProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:medications/medications.dart' show medicationListProvider;
import 'package:records/records.dart';
import 'package:self_report/self_report.dart';
import 'report_flow.dart' show openCheckin;
import 'day_records_screen.dart';
import 'home_widgets.dart';
import 'records_screen.dart';
import '../care/care_entity.dart';
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
/// emergency card, add a first medication). Layout follows the Claude Design
/// HomeScreen: travel banner, check-in hero, streak, nearby/records shortcuts,
/// latest readings (including SpO₂ when logged), then recent reports that open
/// the day detail. Appointments and today's meds live on their own tabs.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    // Real account summary → greeting name. Null while loading / signed out;
    // the greeting label still renders, just without a name.
    final summary = ref.watch(accountSummaryProvider).valueOrNull;
    final member = s.activeFamilyMember;
    final displayName = (member?.name ?? summary?.displayName ?? '').trim();
    final firstName = displayName.split(' ').first;
    final avatarColor = member?.color ?? T.petalAqua;

    return ContentColumn(
      maxWidth: 720,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const PadTop(),

          // App bar: avatar (account switcher) + greeting + bell.
          AppBarRow(children: [
            _AvatarButton(
              initials: accountInitials(displayName),
              color: avatarColor,
              showBadge: s.extraFamily.isNotEmpty,
              onTap: () => showAccountSwitcher(context),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.strings.home.greet, style: Typo.meta(ar: s.rtl)),
                if (firstName.isNotEmpty) Text(firstName, style: Typo.heading(ar: s.rtl).copyWith(fontSize: FS.xl)),
              ]),
            ),
            RoundBtn(icon: LucideIcons.bell, onTap: () {}),
          ]),

          const AwayBanner(),

          // Daily check-in hero — the primary action on this screen.
          const _CheckInSection(),

          // Onboarding nudges — driven by real P001 providers (handle /
          // emergency card / first medication). Each stays hidden until its
          // provider resolves, so signed-out never flashes a wrong nudge.
          const _NudgeSection(),

          // Nearby care + records shortcuts.
          const _NearbyShortcut(),
          const _RecordsShortcut(),

          // Latest readings — only once something has been logged.
          const _LatestMetrics(),

          const _RecentReports(),

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

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({
    required this.initials,
    required this.color,
    required this.showBadge,
    required this.onTap,
  });
  final String initials;
  final Color color;
  final bool showBadge;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Pressable(
      onTap: onTap,
      scale: 0.95,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Avatar(initials: initials, color: color, ar: s.rtl),
          if (showBadge)
            PositionedDirectional(
              bottom: -1,
              end: -1,
              child: Container(
                width: 14,
                height: 14,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: s.accent.main, shape: BoxShape.circle),
                ),
              ),
            ),
        ],
      ),
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
        onStart: () => openCheckin(context),
        onReview: () => s.setTab('trends'),
      ),
      // A streak of zero is not an achievement worth a card.
      if (streak > 0) HomeStreak(days: streak, checkedLast7: checkInsLastDays(history, 7)),
    ]);
  }
}

/// Nearby-care shortcut, with a live directory count.
class _NearbyShortcut extends ConsumerWidget {
  const _NearbyShortcut();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final count = (ref.watch(careDirectoryProvider).valueOrNull ?? const <CareEntity>[]).length;
    return HomeShortcut(
      icon: LucideIcons.mapPin,
      iconBg: T.petalBlue50,
      iconFg: T.petalBlue,
      title: s.strings.care.map_nearby,
      subtitle: '$count ${s.strings.care.map_sub}',
      onTap: () => s.setTab('map'),
    );
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
          foot: (v.systolic! >= 130 || v.diastolic! >= 85) ? s.strings.checkin.bp_high : s.strings.checkin.bp_normal,
          footTone: v.systolic! >= 130 || v.diastolic! >= 85,
        ),
      if (glucose != null)
        MetricTile(
          icon: LucideIcons.droplet,
          label: s.strings.profile.m_glucose,
          value: '$glucose',
          unit: s.strings.checkin.unit_glu,
          foot: glucose >= 140 ? s.strings.checkin.bp_high : s.strings.checkin.bp_normal,
          footTone: glucose >= 140,
        ),
      if (v.spo2 != null)
        MetricTile(
          icon: LucideIcons.wind,
          label: s.strings.profile.m_o2,
          value: '${v.spo2}',
          unit: s.strings.checkin.unit_spo2,
        ),
      if (latest.mood != null)
        MetricTile(
          icon: LucideIcons.smile,
          label: s.strings.profile.m_mood,
          value: moodLabel(s, latest.mood!.score),
        ),
      if (latest.painLevel.value > 0)
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
        child: MetricGrid(tiles: tiles),
      ),
    ]);
  }
}

/// Last three check-ins — Claude Design "recent reports"; each row opens
/// [DayRecordsScreen]. Hidden until the patient has logged at least once.
class _RecentReports extends ConsumerWidget {
  const _RecentReports();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final history = ref.watch(checkInHistoryProvider).valueOrNull ?? const <CheckIn>[];
    if (history.isEmpty) return const SizedBox.shrink();
    final recent = history.take(3).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      RowHead(s.strings.common.recent, action: s.strings.common.see_all, onAction: () => s.setTab('trends'), ar: s.rtl),
      PCard(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: EdgeInsets.zero,
        child: Column(
          children: recent.indexed
              .map((e) => CheckInHistoryRow(
                    checkIn: e.$2,
                    first: e.$1 == 0,
                    onTap: () => DayRecordsScreen.open(context, e.$2),
                  ))
              .toList(),
        ),
      ),
    ]);
  }
}
