import 'package:appointments/appointments.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:self_report/self_report.dart';
import '../app_state.dart';
import '../kit.dart';
import '../tokens.dart';
import '../widgets/balsm_flower.dart';
import 'appointments_screen.dart';

/// Today's check-in, if one has been recorded. Drives the hero's two states.
CheckIn? todayCheckIn(List<CheckIn> history) {
  final now = DateTime.now();
  for (final c in history) {
    final d = c.recordedAt.toLocal();
    if (d.year == now.year && d.month == now.month && d.day == now.day) return c;
  }
  return null;
}

/// Consecutive days ending today (or yesterday) that have a check-in.
///
/// Counting back from yesterday keeps the streak alive during the day before
/// the patient has logged — it only breaks once a whole day is skipped.
int checkInStreak(List<CheckIn> history) {
  if (history.isEmpty) return 0;
  final days = history.map((c) {
    final d = c.recordedAt.toLocal();
    return DateTime(d.year, d.month, d.day);
  }).toSet();

  final now = DateTime.now();
  var cursor = DateTime(now.year, now.month, now.day);
  if (!days.contains(cursor)) {
    cursor = cursor.subtract(const Duration(days: 1));
    if (!days.contains(cursor)) return 0;
  }
  var streak = 0;
  while (days.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

/// `.hero-card` — the daily check-in prompt, or its completed state.
class HomeHero extends StatelessWidget {
  const HomeHero({super.key, required this.done, required this.onStart, required this.onReview});
  final bool done;
  final VoidCallback onStart;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    if (done) {
      return PCard(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(22),
        child: Row(children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: T.petalMint50, shape: BoxShape.circle),
            child: const Icon(LucideIcons.check, size: 28, color: T.petalMint600),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.strings.common.done_lbl,
                  style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: s.accent.main)),
              const SizedBox(height: 2),
              Text(s.strings.common.done_q, style: Typo.subhead(ar: s.rtl)),
            ]),
          ),
          RoundBtn(icon: forwardArrow(context), onTap: onReview),
        ]),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(22),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: s.accent.main,
        borderRadius: BorderRadius.circular(T.rXl),
        boxShadow: s.accent.boxShadow,
      ),
      child: Stack(children: [
        const PositionedDirectional(
          top: -28,
          end: -28,
          child: Opacity(
            opacity: 0.16,
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
              child: BalsmFlower(size: 150),
            ),
          ),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.strings.common.today_lbl,
              style: Typo.bodySm(ar: s.rtl)
                  .copyWith(fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.9))),
          const SizedBox(height: 2),
          Text(s.strings.home.hero_q(s.gender),
              style: Typo.title(ar: s.rtl).copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Pressable(
            onTap: onStart,
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(T.rMd)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(LucideIcons.plusCircle, size: 20, color: s.accent.d),
                const SizedBox(width: 8),
                Text(s.strings.home.hero_cta(s.gender),
                    style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: s.accent.d)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Icon(LucideIcons.clock, size: 15, color: Colors.white.withValues(alpha: 0.9)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(s.strings.home.hero_time,
                  style: Typo.bodySm(ar: s.rtl).copyWith(color: Colors.white.withValues(alpha: 0.9))),
            ),
          ]),
        ]),
      ]),
    );
  }
}

/// `.streak` — ring + copy + flame.
class HomeStreak extends StatelessWidget {
  const HomeStreak({super.key, required this.days});
  final int days;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return PCard(
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        RingProgress(
          // A 7-day ring: the goal is a full week, so it fills and resets.
          progress: (days % 7 == 0 && days > 0) ? 1 : (days % 7) / 7,
          color: s.accent.main,
          label: '$days',
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$days ${s.strings.home.streak}', style: Typo.subhead(ar: s.rtl).copyWith(fontSize: FS.md)),
            const SizedBox(height: 2),
            Text(s.strings.home.streak_help, style: Typo.meta(ar: s.rtl)),
          ]),
        ),
        const Icon(LucideIcons.flame, size: 24, color: T.sun500),
      ]),
    );
  }
}

/// `.metric` tile — label, big value with unit, optional footnote.
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.unit = '',
    this.foot,
    this.footTone,
  });
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final String? foot;

  /// true = worse (danger), false = better (green), null = neutral.
  final bool? footTone;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final numeric = RegExp(r'[0-9]').hasMatch(value);
    final footColor = switch (footTone) {
      true => T.danger,
      false => const Color(0xFF1F6A36),
      null => T.fg3,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(T.rLg),
        border: Border.all(color: T.border),
        boxShadow: T.shadowXs,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 15, color: T.fg3),
          const SizedBox(width: 7),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Flexible(
            child: Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // Numbers stay LTR even in Arabic so "120/80" doesn't flip.
                textDirection: numeric ? TextDirection.ltr : null,
                style: Typo.title(ar: s.rtl).copyWith(fontWeight: FontWeight.w800, height: 1.1)),
          ),
          if (unit.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(unit, style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg3)),
          ],
        ]),
        if (foot != null && foot!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(children: [
            if (footTone != null) ...[
              Icon(footTone! ? LucideIcons.arrowUpRight : LucideIcons.arrowDownRight, size: 14, color: footColor),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(foot!,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: Typo.meta(ar: s.rtl).copyWith(color: footColor)),
            ),
          ]),
        ],
      ]),
    );
  }
}

/// `.card` shortcut row — icon tile, title, subtitle, chevron.
class HomeShortcut extends StatelessWidget {
  const HomeShortcut({
    super.key,
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
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
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(T.rMd)),
          child: Icon(icon, size: 19, color: iconFg),
        ),
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

/// Next upcoming visit, as a compact strip. Hidden when nothing is scheduled.
class UpcomingAppointmentStrip extends ConsumerWidget {
  const UpcomingAppointmentStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final all = ref.watch(appointmentListProvider).valueOrNull ?? const <Appointment>[];
    final now = DateTime.now();
    final upcoming = all.where((a) => a.isUpcoming(now)).toList()..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    if (upcoming.isEmpty) return const SizedBox.shrink();
    final next = upcoming.first;

    return PCard(
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      onTap: () => s.setTab('appts'),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: s.accent.bg, borderRadius: BorderRadius.circular(T.rMd)),
          child: Icon(LucideIcons.calendar, size: 19, color: s.accent.main),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.strings.care.upcoming_appt.toUpperCase(), style: Typo.eyebrow(s.accent.main, ar: s.rtl)),
            const SizedBox(height: 2),
            Text(
              '${next.clinician} · ${formatAppointmentDate(next.startsAt, s)} ${formatAppointmentTime(next.startsAt)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1),
            ),
          ]),
        ),
        Chevron(rtl: s.rtl),
      ]),
    );
  }
}
