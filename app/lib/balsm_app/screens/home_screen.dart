import 'package:core/core.dart';
import 'package:emergency_card/emergency_card.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:medications/medications.dart';
import 'package:records/records.dart';
import 'package:profile/profile.dart';
import 'package:self_report/self_report.dart';
import 'report_flow.dart';
import 'day_records_screen.dart';
import 'home_widgets.dart';
import 'records_screen.dart';
import '../care/care_entity.dart';
import '../app_state.dart';
import '../routes.dart';
import '../kit.dart';
import '../responsive.dart';
import '../tokens.dart';
import '../widgets/account_switcher.dart';
import 'checkin_shared.dart';
import 'personal_details.dart';
import 'profile_subscreens.dart';
import 'care_team_screen.dart';

/// Home tab — P001 patient-MVP scope.
///
/// Ported onto real providers: the greeting name comes from the account
/// summary (not the sample family-account data), and the status cards reflect
/// real on-device state — onboarding nudges (claim handle, set up the
/// emergency card, add a first medication). Layout follows Claude Design
/// home-v2.jsx HomeScreenV2 (with the v1 app bar): travel banner, the check-in
/// card with streak and week strip, latest readings, three shortcut tiles
/// (care team, nearby, records), then recent reports that open the day
/// detail. From 840 wide it is two columns. Appointments and today's meds
/// live on their own tabs.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    // Real account summary → greeting name. Null while loading / signed out;
    // the greeting label still renders, just without a name.
    final summary = ref.watch(accountSummaryProvider).valueOrNull;
    final member = s.activeFamilyMember;
    // The greeting and avatar name whoever's record is actually on screen —
    // always the signed-in user, because `selectFamilyMember` is a
    // session-only visual switch that does not re-point the health profile.
    // Naming the selected member here claimed their readings were below when
    // they were the patient's own.
    final displayName = (summary?.displayName ?? '').trim();
    final firstName = displayName.split(' ').first;
    const avatarColor = T.hueAqua;

    return ContentColumn(
      maxWidth: T.contentMax,
      child: LayoutBuilder(builder: (context, box) {
        // `.hv2 { --g }` — 16 on a phone, 24 from 600; two columns from 840.
        final g = box.maxWidth >= 600 ? 24.0 : 16.0;
        final wide = box.maxWidth >= 840;
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            const PadTop(),

            // App bar: avatar (account switcher) + greeting. The design keeps
            // the v1 header (`BALSM_V1_HEADER`).
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
              // Bell hidden: it had an empty onTap, so it announced itself to a
              // screen reader as a working button and then did nothing. Restore
              // it with the screen it is meant to open.
            ]),

            // `UX Enhancement Screens.html` — "Household · active-account
            // accent": the design keeps whose-data-is-this permanently visible.
            // Here it says the true thing: the member is selected, but their
            // record is not on this device yet, so this is still your own.
            if (member != null) _ViewingBanner(member: member),

            const AwayBanner(),

            Padding(
              padding: EdgeInsetsDirectional.symmetric(horizontal: g),
              child: wide
                  ? const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        flex: 115,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          _CheckInSection(),
                          _NudgeSection(),
                          _LatestMetrics(),
                        ]),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        flex: 100,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          _Shortcuts(row: true),
                          _RecentReports(),
                        ]),
                      ),
                    ])
                  : const Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      _CheckInSection(),
                      // Onboarding nudges — driven by real P001 providers
                      // (handle / emergency card / first medication). Each
                      // stays hidden until its provider resolves, so
                      // signed-out never flashes a wrong nudge.
                      _NudgeSection(),
                      _LatestMetrics(),
                      SizedBox(height: 10),
                      _Shortcuts(),
                      _RecentReports(),
                    ]),
            ),

            const SizedBox(height: 28),
          ],
        );
      }),
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
          iconBg: T.hueMint50,
          iconFg: T.hueMint,
          title: s.strings.home.nudge_handle,
          subtitle: s.strings.home.nudge_handle_sub,
          onTap: () => openPersonalDetails(context),
        ),
      if (needsEmergencyCard)
        _Shortcut(
          icon: LucideIcons.shieldAlert,
          iconBg: T.hueAqua50,
          iconFg: T.hueAqua,
          title: s.strings.home.nudge_ec,
          subtitle: s.strings.home.nudge_ec_sub,
          onTap: () => openEmergency(context),
        ),
      if (needsFirstMedication)
        _Shortcut(
          icon: LucideIcons.pill,
          iconBg: T.hueViolet50,
          iconFg: T.hueViolet,
          title: s.strings.home.nudge_med,
          subtitle: s.strings.home.nudge_med_sub,
          onTap: () => s.setTab(AppTab.meds),
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
      margin: const EdgeInsetsDirectional.only(top: 14),
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

/// The check-in card: today's state, the streak and the last seven days, all
/// from real check-in history.
class _CheckInSection extends ConsumerWidget {
  const _CheckInSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final history = ref.watch(checkInHistoryProvider).valueOrNull ?? const <CheckIn>[];
    return HomeCheckInCard(
      done: todayCheckIn(history) != null,
      streak: checkInStreak(history),
      week: checkInDays(history, 7),
      onStart: () => openCheckin(context),
      onReview: () => s.setTab(AppTab.trends),
    );
  }
}

/// `.h2-shortcuts` — care team, nearby care and records, each with its real
/// count: the patient's own care team, the directory, their documents.
class _Shortcuts extends ConsumerWidget {
  const _Shortcuts({this.row = false});

  /// List rows for the two-column home instead of three tiles across.
  final bool row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final team = (ref.watch(careTeamProvider).valueOrNull ?? const <CareProvider>[]).length;
    final nearby = (ref.watch(careDirectoryProvider).valueOrNull?.entities ?? const <CareEntity>[]).length;
    final records = (ref.watch(recordListProvider).valueOrNull ?? const <RecordDocument>[]).length;
    final tiles = [
      HomeShortcutTile(
        icon: LucideIcons.stethoscope,
        iconBg: T.hueMint50,
        iconFg: T.hueMint600,
        label: s.strings.profile.p_care,
        count: team,
        unit: s.strings.home.sc_providers,
        onTap: () => openCareTeam(context),
        row: row,
      ),
      HomeShortcutTile(
        icon: LucideIcons.mapPin,
        iconBg: T.hueBlue50,
        iconFg: T.hueBlue,
        label: s.strings.care.map_nearby,
        count: nearby,
        unit: s.strings.home.sc_places,
        onTap: () => s.setTab(AppTab.map),
        row: row,
      ),
      HomeShortcutTile(
        icon: LucideIcons.folderHeart,
        iconBg: T.hueViolet50,
        iconFg: T.hueViolet,
        label: s.strings.home.sc_records,
        count: records,
        unit: s.strings.records.rec_documents,
        onTap: () => s.setTab(AppTab.records),
        row: row,
      ),
    ];
    if (row) {
      return Column(children: [
        for (final (i, t) in tiles.indexed) ...[if (i > 0) const SizedBox(height: 8), t],
      ]);
    }
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final (i, t) in tiles.indexed) ...[if (i > 0) const SizedBox(width: 8), Expanded(child: t)],
      ]),
    );
  }
}

/// `.h2-vitals` — the newest value of each reading across check-ins. Hidden
/// until at least one check-in exists, so a new patient sees no empty card.
class _LatestMetrics extends ConsumerWidget {
  const _LatestMetrics();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final history = ref.watch(checkInHistoryProvider).valueOrNull ?? const <CheckIn>[];
    if (history.isEmpty) return const SizedBox.shrink();
    final r = LatestReadings.from(history);
    final glucose = r.glucose;
    final hasBp = r.systolic != null && r.diastolic != null;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      HomeSectionHead(s.strings.checkin.latest,
          action: s.strings.common.see_all, onAction: () => s.setTab(AppTab.trends)),
      HomeVitalsCard(
        bp: hasBp ? '${r.systolic}/${r.diastolic}' : null,
        bpHigh: hasBp && (r.systolic! >= 130 || r.diastolic! >= 85),
        glucose: glucose?.toString(),
        glucoseHigh: glucose != null && glucose >= 140,
        spo2: r.spo2?.toString(),
        mood: r.mood == null ? null : moodLabel(s, r.mood!.score),
        pain: r.pain == null ? null : '${r.pain!.value}/10',
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
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      HomeSectionHead(s.strings.common.recent,
          action: s.strings.common.see_all, onAction: () => s.setTab(AppTab.trends)),
      PCard(
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

/// The design's active-account chrome, told truthfully.
///
/// `selectFamilyMember` is a session-only visual switch — the readings below
/// belong to the signed-in patient whatever the switcher says. Rather than
/// dress the screen in the member's identity (which asserted their data was
/// on screen), this names the member, carries their accent, and states the
/// limit outright. It retires when profile switching actually re-points the
/// data (P00X, which `currentProfileIdProvider` is already shaped for).
class _ViewingBanner extends StatelessWidget {
  const _ViewingBanner({required this.member});
  final FamilyMemberPreview member;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: T.ink50,
        borderRadius: BorderRadius.circular(T.rLg),
        // The member's own tone, as the design's 3px accent rule does.
        border: BorderDirectional(start: BorderSide(color: member.color, width: 3)),
      ),
      child: Row(children: [
        Icon(LucideIcons.users, size: 17, color: member.color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.strings.home.viewing_member(member.name),
                style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg1)),
            const SizedBox(height: 2),
            Text(s.strings.home.viewing_own_data, style: Typo.meta(ar: s.rtl).copyWith(height: 1.4)),
          ]),
        ),
        const SizedBox(width: 8),
        PButton(
          s.strings.home.viewing_switch_back,
          variant: BtnVariant.ghost,
          size: BtnSize.sm,
          accent: s.accent,
          ar: s.rtl,
          onTap: () => s.selectFamilyMember(null),
        ),
      ]),
    );
  }
}
