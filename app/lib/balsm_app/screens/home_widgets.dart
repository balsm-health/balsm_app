import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:core/core.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:self_report/self_report.dart';

import '../app_state.dart';
import '../kit.dart';
import '../routes.dart';

/// Today's check-in, if one has been recorded. Drives the hero's two states.
CheckIn? todayCheckIn(List<CheckIn> history) {
  final now = DateTime.now();
  for (final c in history) {
    final d = c.recordedAt.toLocal();
    if (d.year == now.year && d.month == now.month && d.day == now.day) return c;
  }
  return null;
}

/// One flag per day for the last [n] calendar days, oldest first and today
/// last: whether that day has a check-in. Feeds the week strip.
List<bool> checkInDays(List<CheckIn> history, int n) {
  if (n <= 0) return const [];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final days = history.map((c) {
    final d = c.recordedAt.toLocal();
    return DateTime(d.year, d.month, d.day);
  }).toSet();
  return List.generate(n, (i) => days.contains(today.subtract(Duration(days: n - 1 - i))));
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

/// `home-v2.css` `.h2-checkin` — the daily check-in card: what today asks
/// for (or that it is done), the streak, and the last seven days.
class HomeCheckInCard extends StatelessWidget {
  const HomeCheckInCard({
    required this.done,
    required this.streak,
    required this.week,
    required this.onStart,
    required this.onReview,
    super.key,
    this.question,
    this.note,
    this.cta,
    this.doneLabel,
    this.showTime = true,
  });
  final bool done;
  final int streak;

  /// A family member's card (`HomeMemberV2`) names them: "How is Sara
  /// today?", "Log for Sara", "Logged for Sara today", with no time estimate.
  /// Null keeps the account holder's own copy.
  final String? question;
  final String? note;
  final String? cta;
  final String? doneLabel;
  final bool showTime;

  /// Last seven days, oldest first, today last ([checkInDays]).
  final List<bool> week;
  final VoidCallback onStart;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final ar = s.rtl;
    final eyebrow = done ? s.strings.common.done_lbl : s.strings.common.today_lbl;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.hero),
        border: Border.all(color: AppColors.hairlineSoft),
        boxShadow: AppShadows.card,
      ),
      child: Stack(
        children: [
          // `.h2-checkin::before` — the accent wash in the top end corner.
          PositionedDirectional(
            top: -60,
            end: -60,
            child: IgnorePointer(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [s.accent.bg, s.accent.bg.withValues(alpha: 0)]),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        ar ? eyebrow : eyebrow.toUpperCase(),
                        style: Typo.eyebrow(done ? AppColors.hueMint600 : s.accent.d, ar: ar)
                            .copyWith(fontSize: ar ? FontSizes.meta : FontSizes.eyebrow),
                      ),
                    ),
                    // A streak of zero is not an achievement worth a pill.
                    if (streak > 0) _StreakPill(days: streak),
                  ],
                ),
                const SizedBox(height: 8),
                if (done)
                  Pressable(
                    onTap: onReview,
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(color: AppColors.hueMint50, shape: BoxShape.circle),
                          child: const Icon(LucideIcons.check, size: 22, color: AppColors.hueMint600),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(doneLabel ?? s.strings.common.done_q, style: _cardTitle(ar))),
                        Chevron(rtl: ar, color: AppColors.textHint),
                      ],
                    ),
                  )
                else ...[
                  Text(question ?? s.strings.home.hero_q(s.gender), style: _cardTitle(ar)),
                  const SizedBox(height: 6),
                  Text(note ?? s.strings.home.hero_disclaimer, style: Typo.meta(ar: ar).copyWith(height: 1.45)),
                  const SizedBox(height: 12),
                  // `.h2-ci-actions` — the button at the start, the time beside it,
                  // wrapping under it when the row runs out (long Arabic copy, large
                  // text). IntrinsicWidth keeps the button's tap-target wrapper from
                  // taking the whole line.
                  Wrap(
                    spacing: 14,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      IntrinsicWidth(
                        child: PButton(
                          cta ?? s.strings.home.hero_cta(s.gender),
                          icon: LucideIcons.plus,
                          accent: s.accent,
                          ar: ar,
                          onTap: onStart,
                        ),
                      ),
                      if (showTime)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(LucideIcons.clock, size: 14, color: AppColors.textTertiary),
                            const SizedBox(width: 6),
                            Text(
                              s.strings.home.hero_time,
                              style: Typo.meta(ar: ar).copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                _WeekStrip(week: week),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// `.h2-ci-q` / `.h2-ci-done .grow`.
  static TextStyle _cardTitle(bool ar) => Typo.heading(ar: ar)
      .copyWith(fontWeight: FontWeight.w800, height: 1.2, letterSpacing: ar ? 0 : -0.42, color: AppColors.textPrimary);
}

/// `.h2-streak` — flame, count, and the word for it.
class _StreakPill extends StatelessWidget {
  const _StreakPill({required this.days});
  final int days;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: AppColors.warningBackground, borderRadius: BorderRadius.circular(AppRadii.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.flame, size: 14, color: AppColors.onWarningBackground),
          const SizedBox(width: 5),
          Text(
            '$days',
            style: Typo.num(size: FontSizes.meta, weight: FontWeight.w700, color: AppColors.onWarningBackground),
          ),
          const SizedBox(width: 4),
          Text(
            s.strings.home.streak,
            style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: AppColors.onWarningBackground),
          ),
        ],
      ),
    );
  }
}

/// `.h2-week` — one dot per day for the last seven, today last. Weekday
/// letters come from the platform's localizations, so they read right in
/// Arabic too.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.week});
  final List<bool> week;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final s7 = s.strings.home;
    final letters = MaterialLocalizations.of(context).narrowWeekdays; // Sunday first
    final now = DateTime.now();
    final logged = week.where((d) => d).length;
    return Semantics(
      label: s7.streak_help(s.gender, logged),
      excludeSemantics: true,
      child: Column(
        children: [
          const _DashedRule(),
          const SizedBox(height: 12),
          Row(
            children: week.indexed.map((e) {
              final (i, on) = e;
              final today = i == week.length - 1;
              final day = now.subtract(Duration(days: week.length - 1 - i));
              return Expanded(
                child: Column(
                  children: [
                    _DayDot(on: on, today: today, accent: s.accent.main),
                    const SizedBox(height: 4),
                    Text(
                      letters[day.weekday % 7],
                      style: Typo.meta(ar: s.rtl).copyWith(
                        fontSize: FontSizes.eyebrow,
                        fontWeight: FontWeight.w600,
                        color: today ? AppColors.textPrimary : AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// `.h2-dot` — filled with a check when logged, a solid ring for today
/// before it is, a dashed ring otherwise.
class _DayDot extends StatelessWidget {
  const _DayDot({required this.on, required this.today, required this.accent});
  final bool on;
  final bool today;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (on) {
      return Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
        child: const Icon(LucideIcons.check, size: 12, color: AppColors.white),
      );
    }
    if (today) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: accent, width: 1.5)),
      );
    }
    return const DashedBorder(
      radius: 12,
      strokeWidth: 1.5,
      dash: 3,
      gap: 3,
      child: SizedBox(width: 24, height: 24),
    );
  }
}

/// `border-top: 1px dashed var(--v2-line)` above the week strip.
class _DashedRule extends StatelessWidget {
  const _DashedRule();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 1, width: double.infinity, child: CustomPaint(painter: _DashedRulePainter()));
}

class _DashedRulePainter extends CustomPainter {
  const _DashedRulePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.hairline
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 7) {
      canvas.drawLine(Offset(x, 0.5), Offset(math.min(x + 4, size.width), 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(_DashedRulePainter oldDelegate) => false;
}

/// `.h2-vitals` — the latest blood pressure large on top, then glucose,
/// oxygen, mood and pain in a two-by-two grid. A reading not logged yet
/// shows a dash; nothing here is a sample value.
class HomeVitalsCard extends StatelessWidget {
  const HomeVitalsCard({
    required this.bp,
    required this.bpHigh,
    required this.glucose,
    required this.glucoseHigh,
    required this.spo2,
    required this.mood,
    required this.pain,
    super.key,
  })  : weight = null,
        weighedOn = null,
        height = null,
        pulse = null,
        isChild = false;

  /// A child's readings (home-mc.jsx `HomeMemberV2`, `child`): weight in the
  /// big cell with the day it was measured, then height, pulse, oxygen and
  /// pain. A child's blood pressure, glucose and mood are not tracked.
  const HomeVitalsCard.child({
    required this.weight,
    required this.weighedOn,
    required this.height,
    required this.pulse,
    required this.spo2,
    required this.pain,
    super.key,
  })  : bp = null,
        bpHigh = false,
        glucose = null,
        glucoseHigh = false,
        mood = null,
        isChild = true;

  final bool isChild;

  /// Child only: kilograms, the day it was measured, centimetres, beats a minute.
  final String? weight;
  final String? weighedOn;
  final String? height;
  final String? pulse;

  /// `systolic/diastolic`, or null when not logged.
  final String? bp;
  final bool bpHigh;
  final String? glucose;
  final bool glucoseHigh;
  final String? spo2;
  final String? mood;
  final String? pain;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final ar = s.rtl;
    final c = s.strings.checkin;
    final p = s.strings.profile;
    const hairline = BorderSide(color: AppColors.hairlineSoft);
    final big = isChild ? weight : bp;
    final cells = isChild
        ? [
            _VitalCell(
              icon: LucideIcons.ruler,
              color: AppColors.hueAqua,
              label: s.strings.home.m_height,
              value: height,
              unit: s.strings.home.unit_cm,
            ),
            _VitalCell(
              icon: LucideIcons.heartPulse,
              color: AppColors.hueViolet,
              label: p.m_pulse,
              value: pulse,
              unit: c.unit_bpm,
            ),
            _VitalCell(icon: LucideIcons.wind, color: AppColors.hueAqua, label: p.m_o2, value: spo2, unit: c.unit_spo2),
            _VitalCell(icon: LucideIcons.thermometer, color: AppColors.danger, label: p.m_pain, value: pain),
          ]
        : [
            _VitalCell(
              icon: LucideIcons.droplet,
              color: AppColors.hueMint600,
              label: p.m_glucose,
              value: glucose,
              unit: c.unit_glu,
              foot: glucoseHigh ? c.bp_high : null,
            ),
            _VitalCell(icon: LucideIcons.wind, color: AppColors.hueAqua, label: p.m_o2, value: spo2, unit: c.unit_spo2),
            _VitalCell(icon: LucideIcons.smile, color: AppColors.hueBlue, label: p.m_mood, value: mood, numeric: false),
            _VitalCell(icon: LucideIcons.thermometer, color: AppColors.danger, label: p.m_pain, value: pain),
          ];
    Widget pair(int a, {required bool top}) => IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration:
                      BoxDecoration(border: BorderDirectional(end: hairline, top: top ? BorderSide.none : hairline)),
                  child: cells[a],
                ),
              ),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(border: Border(top: top ? BorderSide.none : hairline)),
                  child: cells[a + 1],
                ),
              ),
            ],
          ),
        );
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: AppColors.hairlineSoft),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 12),
            decoration: const BoxDecoration(border: Border(bottom: hairline)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isChild)
                  _VitalLabel(icon: LucideIcons.scale, color: AppColors.hueBlue, label: p.m_weight, size: 15)
                else
                  _VitalLabel(icon: LucideIcons.activity, color: AppColors.hueViolet, label: p.m_bp, size: 15),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: big ?? '—',
                              style: Typo.num(size: FontSizes.hero).copyWith(height: 1, letterSpacing: -1.2),
                            ),
                            if (big != null) TextSpan(text: ' ${isChild ? c.unit_kg : c.unit_bp}', style: _unit(ar)),
                          ],
                        ),
                        textDirection: TextDirection.ltr,
                        textAlign: ar ? TextAlign.right : TextAlign.left,
                      ),
                    ),
                    if (isChild && big != null && weighedOn != null) ...[
                      const SizedBox(width: 12),
                      Padding(
                        padding: const EdgeInsetsDirectional.only(bottom: 4),
                        child: Text(weighedOn!, textDirection: TextDirection.ltr, style: Typo.meta(ar: ar)),
                      ),
                    ],
                    if (!isChild && bp != null) ...[
                      const SizedBox(width: 12),
                      Padding(
                        padding: const EdgeInsetsDirectional.only(bottom: 4),
                        child: Pill(
                          bpHigh ? c.bp_high : c.bp_normal,
                          kind: bpHigh ? PillKind.warn : PillKind.success,
                          ar: ar,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          pair(0, top: true),
          pair(2, top: false),
        ],
      ),
    );
  }

  static TextStyle _unit(bool ar) =>
      Typo.meta(ar: ar).copyWith(fontWeight: FontWeight.w600, letterSpacing: 0, height: 1);
}

/// `.h2-vlab` — small coloured icon and label.
class _VitalLabel extends StatelessWidget {
  const _VitalLabel({required this.icon, required this.color, required this.label, this.size = 14});
  final IconData icon;
  final Color color;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Row(
      children: [
        Icon(icon, size: size, color: color),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// `.h2-v` — one cell of the two-by-two grid.
class _VitalCell extends StatelessWidget {
  const _VitalCell({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.unit,
    this.foot,
    this.numeric = true,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String? value;
  final String? unit;
  final String? foot;

  /// Mono digits, laid out left to right in both languages (`.h2-vval.num`).
  final bool numeric;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final ar = s.rtl;
    final v = value;
    final style = numeric && v != null
        ? Typo.num(size: FontSizes.heading)
        : Typo.subhead(ar: ar).copyWith(fontWeight: FontWeight.w700);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _VitalLabel(icon: icon, color: color, label: label),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: v ?? '—', style: style),
                if (v != null && unit != null) TextSpan(text: ' $unit', style: HomeVitalsCard._unit(ar)),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textDirection: numeric ? TextDirection.ltr : null,
            textAlign: ar ? TextAlign.right : TextAlign.left,
          ),
          if (foot case final foot?) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(LucideIcons.arrowUpRight, size: 13, color: AppColors.warningInk),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    foot,
                    style: Typo.meta(ar: ar).copyWith(
                      fontSize: FontSizes.eyebrow,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warningInk,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// `.h2-sec` — a small section label with an optional action at the end.
/// Uppercase and tracked in Latin script; plain and larger in Arabic.
class HomeSectionHead extends StatelessWidget {
  const HomeSectionHead(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final ar = s.rtl;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 20, bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                ar ? title : title.toUpperCase(),
                style: ar
                    ? Typo.bodySm(ar: true).copyWith(fontWeight: FontWeight.w700, color: AppColors.textTertiary)
                    : Typo.eyebrow(AppColors.textTertiary),
              ),
            ),
          ),
          if (action case final action?)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
                minimumSize: const Size(44, 44),
                foregroundColor: s.accent.d,
              ),
              child: Text(action, style: Typo.bodySm(ar: ar).copyWith(fontWeight: FontWeight.w600, color: s.accent.d)),
            ),
        ],
      ),
    );
  }
}

/// `.metric` tile — label, big value with unit, optional footnote.
///
/// `.metric-grid` is `1fr 1fr` on a phone and
/// `repeat(auto-fit, minmax(150px, 1fr))` from the medium window class, where
/// the column is wide enough to hold more than two tiles.
///
/// CSS grid rows are **auto height**: a row is as tall as its tallest item and
/// no taller. A `GridView` with a fixed `childAspectRatio` cannot express that —
/// it invents a height, which leaves dead space when the content is short and
/// overflows when Dynamic Type makes it tall. Two `Expanded` cells inside an
/// [IntrinsicHeight] row reproduce the grid exactly, including
/// `align-items: stretch` (both tiles in a row share the taller height) and a
/// lone trailing tile occupying only its own column.
class MetricGrid extends StatelessWidget {
  const MetricGrid({required this.tiles, super.key, this.gap = 12});

  final List<Widget> tiles;
  final double gap;

  /// `minmax(150px, 1fr)` — the track floor auto-fit counts columns against.
  static const _colMin = 150.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final columns = windowClassOf(context) == BalsmWindowClass.compact
            ? 2
            : math.max(1, ((c.maxWidth + gap) / (_colMin + gap)).floor());
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: gap,
          children: tiles
              .slices(columns)
              .map<Widget>(
                (row) => IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: gap,
                    children: [
                      for (final tile in row) Expanded(child: tile),
                      // A short final row keeps its columns rather than stretching
                      // the tiles it does have across the full width.
                      for (var i = row.length; i < columns; i++) const Expanded(child: SizedBox.shrink()),
                    ],
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class MetricTile extends StatelessWidget {
  const MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    super.key,
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
    final numeric = RegExp('[0-9]').hasMatch(value);
    final footColor = switch (footTone) {
      true => AppColors.danger,
      false => AppColors.hueMintInk,
      null => AppColors.textTertiary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: AppColors.textTertiary),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                // The reading is the hero of the tile — it must never be cut. A
                // wide unit (Arabic "ملم زئبق" is ~3x "mmHg") plus a 3-digit
                // systolic overflows the 143pt content box, and CSS would reflow
                // where a fixed-height tile can only ellipsize. Scale the value
                // down instead so the full number stays legible.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    value,
                    maxLines: 1,
                    // Numbers stay LTR even in Arabic so "120/80" doesn't flip.
                    textDirection: numeric ? TextDirection.ltr : null,
                    style: Typo.title(ar: s.rtl).copyWith(fontWeight: FontWeight.w800, height: 1.1),
                  ),
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    unit,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: AppColors.textTertiary),
                  ),
                ),
              ],
            ],
          ),
          if (foot case final footValue? when foot!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (footTone case final footTone?) ...[
                  Icon(footTone ? LucideIcons.arrowUpRight : LucideIcons.arrowDownRight, size: 14, color: footColor),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    footValue,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Typo.meta(ar: s.rtl).copyWith(color: footColor),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// `.h2-sc` — a shortcut tile: icon square, label, and a count. Stacked in
/// the phone's three-across row; [row] lays it out as a list row for the
/// two-column home.
class HomeShortcutTile extends StatelessWidget {
  const HomeShortcutTile({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.label,
    required this.count,
    required this.unit,
    required this.onTap,
    super.key,
    this.row = false,
    this.value,
  });
  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String label;
  final int count;

  /// Shown in place of [count] when the figure is not a number (a blood
  /// type), or empty to show [unit] alone.
  final String? value;
  final String unit;
  final VoidCallback onTap;
  final bool row;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final ar = s.rtl;
    final iconBox = Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(AppRadii.iconSquare)),
      child: Icon(icon, size: 20, color: iconFg),
    );
    final title = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Typo.bodySm(ar: ar).copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary, height: 1.25),
    );
    final sub = Text.rich(
      TextSpan(
        children: [
          if (value != '')
            TextSpan(
              text: value ?? '$count',
              style: Typo.num(size: FontSizes.eyebrow, weight: FontWeight.w700, color: AppColors.textSecondary),
            ),
          TextSpan(text: value == '' ? unit : ' $unit'),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Typo.meta(ar: ar).copyWith(fontSize: FontSizes.eyebrow),
    );
    return Semantics(
      button: true,
      child: Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.tile),
            border: Border.all(color: AppColors.hairlineSoft),
            boxShadow: AppShadows.card,
          ),
          child: row
              ? Row(
                  children: [
                    iconBox,
                    const SizedBox(width: 12),
                    Expanded(child: title),
                    const SizedBox(width: 8),
                    sub,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    iconBox,
                    const SizedBox(height: 8),
                    title,
                    const SizedBox(height: 2),
                    sub,
                  ],
                ),
        ),
      ),
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
    const ink = AppColors.onSun;
    return Container(
      margin: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: AppColors.sun500, borderRadius: BorderRadius.circular(AppRadii.lg)),
      child: Row(
        children: [
          const Icon(LucideIcons.plane, size: 20, color: ink),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${s.strings.home.away_banner} · ${s.country.name(kCatalog, locale: s.lang.value)}',
                  style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: ink),
                ),
                if (emergency.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '${s.strings.emergency.emergency} '),
                        TextSpan(
                          text: emergency,
                          style: Typo.num(size: FontSizes.bodySm, weight: FontWeight.w800, color: ink),
                        ),
                      ],
                    ),
                    style: Typo.meta(ar: s.rtl).copyWith(color: ink.withValues(alpha: 0.85)),
                  ),
                ],
              ],
            ),
          ),
          RoundBtn(
            icon: forwardArrow(context),
            semanticLabel: s.strings.common.a11y_next,
            bg: AppColors.onSunWash,
            fg: ink,
            onTap: () => s.setTab(AppTab.profile),
          ),
        ],
      ),
    );
  }
}
