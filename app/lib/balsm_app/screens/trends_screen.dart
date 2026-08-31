import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:self_report/self_report.dart';
import '../app_state.dart';
import '../kit.dart';
import '../responsive.dart';
import '../tokens.dart';
import '../widgets/line_chart.dart';
import '../widgets/mood_face.dart';
import 'checkin_shared.dart';

/// How far back the charts look.
enum TrendRange { week, month, quarter }

extension on TrendRange {
  int get days => switch (this) { TrendRange.week => 7, TrendRange.month => 30, TrendRange.quarter => 90 };
  String label(PatientAppState s) => switch (this) {
        TrendRange.week => s.strings.checkin.range_w,
        TrendRange.month => s.strings.checkin.range_m,
        TrendRange.quarter => s.strings.checkin.range_3m,
      };
}

/// Trends — vitals over time plus the check-in history list.
///
/// Reads real on-device check-ins; every series is derived from what the
/// patient actually logged, so a metric with no readings hides its card rather
/// than drawing an empty axis.
class TrendsScreen extends ConsumerStatefulWidget {
  const TrendsScreen({super.key});

  @override
  ConsumerState<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends ConsumerState<TrendsScreen> {
  TrendRange _range = TrendRange.week;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final history = ref.watch(checkInHistoryProvider).valueOrNull ?? const <CheckIn>[];

    final cutoff = DateTime.now().subtract(Duration(days: _range.days));
    // `findAll` is newest-first; charts read left-to-right in time order.
    final inRange = history.where((c) => c.recordedAt.isAfter(cutoff)).toList().reversed.toList();

    final sys = <double>[], dia = <double>[], glucose = <double>[];
    for (final c in inRange) {
      final v = c.vitals;
      if (v.systolic != null && v.diastolic != null) {
        sys.add(v.systolic!.toDouble());
        dia.add(v.diastolic!.toDouble());
      }
      final g = v.glucoseFasting ?? v.glucosePostMeal ?? v.glucoseRandom;
      if (g != null) glucose.add(g.toDouble());
    }

    return ContentColumn(
      maxWidth: 720,
      child: ListView(padding: EdgeInsets.zero, children: [
        const PadTop(),
        AppBarRow(children: [
          RoundBtn(icon: backArrow(context), onTap: () => s.setTab('home')),
          const SizedBox(width: 12),
          Expanded(child: Text(s.strings.checkin.trends, style: Typo.heading(ar: s.rtl))),
          _RangeTabs(value: _range, onChange: (r) => setState(() => _range = r)),
        ]),
        if (sys.isNotEmpty)
          _ChartCard(
            title: s.strings.profile.m_bp,
            value: '${_avg(sys).round()}/${_avg(dia).round()}',
            unit: s.strings.checkin.unit_bp,
            series: [ChartSeries(sys, T.petalViolet), ChartSeries(dia, T.petalBlue)],
            legend: [(s.strings.checkin.sys, T.petalViolet), (s.strings.checkin.dia, T.petalBlue)],
          ),
        if (glucose.isNotEmpty)
          _ChartCard(
            margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            title: s.strings.profile.m_glucose,
            value: _avg(glucose).round().toString(),
            unit: s.strings.checkin.unit_glu,
            series: [ChartSeries(glucose, T.petalMint600)],
          ),
        if (sys.isEmpty && glucose.isEmpty) _NoReadings(range: _range),
        RowHead(s.strings.records.reports, ar: s.rtl),
        if (history.isEmpty)
          PCard(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 36),
            child: Column(children: [
              const Icon(LucideIcons.clipboardList, size: 36, color: T.fg4),
              const SizedBox(height: 14),
              Text(s.strings.checkin.no_checkins,
                  textAlign: TextAlign.center,
                  style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg2)),
            ]),
          )
        else
          PCard(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                for (final (i, c) in history.indexed) _HistoryRow(checkIn: c, first: i == 0),
              ],
            ),
          ),
        const SizedBox(height: 24),
      ]),
    );
  }

  static double _avg(List<double> xs) => xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;
}

/// `.range-tabs` — week / month / 3 months.
class _RangeTabs extends StatelessWidget {
  const _RangeTabs({required this.value, required this.onChange});
  final TrendRange value;
  final ValueChanged<TrendRange> onChange;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (final r in TrendRange.values) ...[
        GestureDetector(
          onTap: () => onChange(r),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: r == value ? T.ink100 : Colors.transparent,
              borderRadius: BorderRadius.circular(T.rPill),
            ),
            child: Text(r.label(s),
                style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: r == value ? T.fg1 : T.fg3)),
          ),
        ),
        if (r != TrendRange.values.last) const SizedBox(width: 6),
      ],
    ]);
  }
}

/// `.chart-card` — title + average on one line, the plot, an optional legend.
class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.series,
    this.legend = const [],
    this.margin,
  });
  final String title;
  final String value;
  final String unit;
  final List<ChartSeries> series;
  final List<(String, Color)> legend;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return PCard(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(title, style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, fontSize: FS.md)),
          Row(children: [
            Text('${s.strings.checkin.avg} ', style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
            Text(value, textDirection: TextDirection.ltr, style: Typo.num(size: FS.sm, color: T.fg1)),
            Text(' $unit', style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
          ]),
        ]),
        const SizedBox(height: 6),
        LineChartView(series: series, rtl: s.rtl),
        if (legend.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(children: [
            for (final (label, color) in legend) ...[
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(label, style: Typo.meta(ar: s.rtl)),
              const SizedBox(width: 16),
            ],
          ]),
        ],
      ]),
    );
  }
}

class _NoReadings extends StatelessWidget {
  const _NoReadings({required this.range});
  final TrendRange range;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return PCard(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 36),
      child: Column(children: [
        const Icon(LucideIcons.activity, size: 36, color: T.fg4),
        const SizedBox(height: 14),
        Text(s.strings.checkin.no_readings,
            textAlign: TextAlign.center,
            style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg2)),
      ]),
    );
  }
}

/// `.history-row` — day chip, vitals summary, mood face, pain badge.
class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.checkIn, required this.first});
  final CheckIn checkIn;
  final bool first;

  static const _monthsEn = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
  static const _monthsAr = ['ينا', 'فبر', 'مار', 'أبر', 'ماي', 'يون', 'يول', 'أغس', 'سبت', 'أكت', 'نوف', 'ديس'];

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final d = checkIn.recordedAt;
    final v = checkIn.vitals;
    final pain = checkIn.painLevel.value;
    final info = painInfo(s, pain);
    final glucose = v.glucoseFasting ?? v.glucosePostMeal ?? v.glucoseRandom;

    return Container(
      decoration: BoxDecoration(border: first ? null : const Border(top: BorderSide(color: T.ink100))),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(children: [
        SizedBox(
          width: 50,
          child: Column(children: [
            Text(d.day.toString(),
                style: Typo.num(size: FS.lg, weight: FontWeight.w800, color: T.fg1).copyWith(height: 1)),
            Text((s.rtl ? _monthsAr : _monthsEn)[d.month - 1],
                style: Typo.meta(ar: s.rtl).copyWith(fontSize: FS.xs2, letterSpacing: s.rtl ? 0 : 1.1)),
          ]),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            if (v.systolic != null && v.diastolic != null) ...[
              const Icon(LucideIcons.activity, size: 14, color: T.petalViolet),
              Text('${v.systolic}/${v.diastolic}',
                  textDirection: TextDirection.ltr, style: Typo.num(size: FS.sm, color: T.fg1)),
            ],
            if (glucose != null) ...[
              const Icon(LucideIcons.droplet, size: 14, color: T.petalMint600),
              Text('$glucose', style: Typo.num(size: FS.sm, color: T.fg1)),
            ],
          ]),
        ),
        if (checkIn.mood != null) ...[
          MoodFace(level: checkIn.mood!.score, size: 26, color: moodColors[checkIn.mood!.score - 1]),
          const SizedBox(width: 10),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: info.color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(T.rPill),
          ),
          child: Text('$pain', style: Typo.num(size: FS.xs, color: info.color)),
        ),
      ]),
    );
  }
}
