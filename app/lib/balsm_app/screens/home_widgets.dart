import 'package:collection/collection.dart';
import 'package:core/core.dart' show CountryCodeL10n;
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:self_report/self_report.dart';
import '../app_state.dart';
import '../kit.dart';
import '../tokens.dart';
import '../widgets/balsm_flower.dart';

/// Today's check-in, if one has been recorded. Drives the hero's two states.
CheckIn? todayCheckIn(List<CheckIn> history) {
  final now = DateTime.now();
  for (final c in history) {
    final d = c.recordedAt.toLocal();
    if (d.year == now.year && d.month == now.month && d.day == now.day) return c;
  }
  return null;
}

/// How many of the last [n] calendar days (including today) have a check-in.
int checkInsLastDays(List<CheckIn> history, int n) {
  if (history.isEmpty || n <= 0) return 0;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final start = today.subtract(Duration(days: n - 1));
  final days = history.map((c) {
    final d = c.recordedAt.toLocal();
    return DateTime(d.year, d.month, d.day);
  }).toSet();
  return Iterable.generate(n, (i) => start.add(Duration(days: i))).where(days.contains).length;
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
          const SizedBox(height: 2),
          Text(s.strings.home.hero_disclaimer,
              style: Typo.meta(ar: s.rtl).copyWith(color: Colors.white.withValues(alpha: 0.85))),
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
  const HomeStreak({super.key, required this.days, required this.checkedLast7});
  final int days;
  final int checkedLast7;

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
            Text(s.strings.home.streak_help(s.gender, checkedLast7), style: Typo.meta(ar: s.rtl)),
          ]),
        ),
        const Icon(LucideIcons.flame, size: 24, color: T.sun500),
      ]),
    );
  }
}

/// `.metric` tile — label, big value with unit, optional footnote.
/// `.metric-grid` — `grid-template-columns: 1fr 1fr; gap: 12px`.
///
/// CSS grid rows are **auto height**: a row is as tall as its tallest item and
/// no taller. A `GridView` with a fixed `childAspectRatio` cannot express that —
/// it invents a height, which leaves dead space when the content is short and
/// overflows when Dynamic Type makes it tall. Two `Expanded` cells inside an
/// [IntrinsicHeight] row reproduce the grid exactly, including
/// `align-items: stretch` (both tiles in a row share the taller height) and a
/// lone trailing tile occupying only its own column.
class MetricGrid extends StatelessWidget {
  const MetricGrid({super.key, required this.tiles, this.gap = 12});

  final List<Widget> tiles;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: gap,
      children: tiles
          .slices(2)
          .map<Widget>((pair) => IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: gap, children: [
                  Expanded(child: pair.first),
                  // An odd final tile keeps its single column rather than stretching.
                  Expanded(child: pair.length > 1 ? pair[1] : const SizedBox.shrink()),
                ]),
              ))
          .toList(),
    );
  }
}

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
            // The reading is the hero of the tile — it must never be cut. A
            // wide unit (Arabic "ملم زئبق" is ~3x "mmHg") plus a 3-digit
            // systolic overflows the 143pt content box, and CSS would reflow
            // where a fixed-height tile can only ellipsize. Scale the value
            // down instead so the full number stays legible.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(value,
                  maxLines: 1,
                  // Numbers stay LTR even in Arabic so "120/80" doesn't flip.
                  textDirection: numeric ? TextDirection.ltr : null,
                  style: Typo.title(ar: s.rtl).copyWith(fontWeight: FontWeight.w800, height: 1.1)),
            ),
          ),
          if (unit.isNotEmpty) ...[
            const SizedBox(width: 4),
            Flexible(
              child: Text(unit,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg3)),
            ),
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

/// Shown when the account country is not Egypt — Claude Design travel banner.
class AwayBanner extends StatelessWidget {
  const AwayBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    if (s.isHomeCountry) return const SizedBox.shrink();
    final emergency = s.country.emergencyNumber;
    const ink = Color(0xFF3A2E05);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: T.sun500, borderRadius: BorderRadius.circular(T.rLg)),
      child: Row(children: [
        const Icon(LucideIcons.plane, size: 20, color: ink),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              '${s.strings.home.away_banner} · ${s.country.name(kCatalog, locale: s.lang.value)}',
              style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: ink),
            ),
            if (emergency.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: '${s.strings.emergency.emergency} '),
                  TextSpan(text: emergency, style: Typo.num(size: FS.sm, weight: FontWeight.w800, color: ink)),
                ]),
                style: Typo.meta(ar: s.rtl).copyWith(color: ink.withValues(alpha: 0.85)),
              ),
            ],
          ]),
        ),
        RoundBtn(icon: forwardArrow(context), bg: const Color(0x1F3A2E05), fg: ink, onTap: () => s.setTab('profile')),
      ]),
    );
  }
}
