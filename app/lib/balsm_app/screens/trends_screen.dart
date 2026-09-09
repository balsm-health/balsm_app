import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:self_report/self_report.dart';
import '../app_state.dart';
import '../kit.dart';
import '../responsive.dart';
import '../tokens.dart';
import '../widgets/line_chart.dart';
import 'checkin_shared.dart';
import 'day_records_screen.dart';

/// How far back the charts look.
enum TrendRange { week, month, quarter }

enum _TrendMetric { bp, glucose, pain, weight }

extension on _TrendMetric {
  String label(PatientAppState s) => switch (this) {
        _TrendMetric.bp => s.strings.profile.m_bp,
        _TrendMetric.glucose => s.strings.profile.m_glucose,
        _TrendMetric.pain => s.strings.profile.m_pain,
        _TrendMetric.weight => s.strings.profile.m_weight,
      };
}

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
/// than drawing an empty axis. Filter chips match the Claude Design TrendsScreen.
class TrendsScreen extends ConsumerStatefulWidget {
  const TrendsScreen({super.key});

  @override
  ConsumerState<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends ConsumerState<TrendsScreen> {
  TrendRange _range = TrendRange.week;
  final _visible = {_TrendMetric.bp, _TrendMetric.glucose, _TrendMetric.pain, _TrendMetric.weight};

  void _toggle(_TrendMetric m) {
    setState(() {
      if (_visible.contains(m)) {
        if (_visible.length > 1) _visible.remove(m);
      } else {
        _visible.add(m);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final history = ref.watch(checkInHistoryProvider).valueOrNull ?? const <CheckIn>[];

    final cutoff = DateTime.now().subtract(Duration(days: _range.days));
    // `findAll` is newest-first; charts read left-to-right in time order.
    final inRange = history.where((c) => c.recordedAt.isAfter(cutoff)).toList().reversed.toList();

    // Systolic and diastolic are charted as a pair, so a reading missing either
    // contributes to neither — filter once and read both off the same rows.
    final bp = inRange.where((c) => c.vitals.systolic != null && c.vitals.diastolic != null);
    final sys = bp.map((c) => c.vitals.systolic!.toDouble()).toList();
    final dia = bp.map((c) => c.vitals.diastolic!.toDouble()).toList();
    final glucose = inRange
        .map((c) => c.vitals.glucoseFasting ?? c.vitals.glucosePostMeal ?? c.vitals.glucoseRandom)
        .nonNulls
        .map((g) => g.toDouble())
        .toList();
    final pain = inRange.map((c) => c.painLevel.value.toDouble()).toList();
    final weight = inRange.map((c) => c.vitals.weightKg).nonNulls.toList();

    // Every metric that can appear is one line of this literal: switched on and
    // holding readings. Spacing between cards is applied where they are laid
    // out, so nothing here depends on how many came before it.
    const chartMargin = EdgeInsets.fromLTRB(20, 0, 20, 0);
    final charts = <Widget>[
      if (_visible.contains(_TrendMetric.bp) && sys.isNotEmpty)
        _ChartCard(
          title: s.strings.profile.m_bp,
          value: '${_avg(sys).round()}/${_avg(dia).round()}',
          unit: s.strings.checkin.unit_bp,
          series: [ChartSeries(sys, T.petalViolet), ChartSeries(dia, T.petalBlue)],
          legend: [(s.strings.checkin.sys, T.petalViolet), (s.strings.checkin.dia, T.petalBlue)],
          margin: chartMargin,
        ),
      if (_visible.contains(_TrendMetric.glucose) && glucose.isNotEmpty)
        _ChartCard(
          title: s.strings.profile.m_glucose,
          value: _avg(glucose).round().toString(),
          unit: s.strings.checkin.unit_glu,
          series: [ChartSeries(glucose, T.petalMint600)],
          margin: chartMargin,
        ),
      if (_visible.contains(_TrendMetric.pain) && pain.isNotEmpty)
        _ChartCard(
          title: s.strings.profile.m_pain,
          value: _avg(pain).toStringAsFixed(1),
          unit: '/10',
          series: [ChartSeries(pain, T.danger)],
          margin: chartMargin,
        ),
      if (_visible.contains(_TrendMetric.weight) && weight.isNotEmpty)
        _ChartCard(
          title: s.strings.profile.m_weight,
          value: _fmtWeight(weight.last),
          unit: s.strings.checkin.unit_kg,
          series: [ChartSeries(weight, T.petalBlue)],
          margin: chartMargin,
          showAvg: false,
        ),
    ];

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
        // Metric filter — a dropdown selector (the design replaced the chip
        // row with one): trigger summarising the selection, opening a
        // checkbox panel that closes on an outside tap.
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: _MetricsDropdown(visible: _visible, onToggle: _toggle),
          ),
        ),
        if (charts.isEmpty)
          _NoReadings(range: _range)
        else
          // Flex.spacing gives the 14pt between cards; the first card gets none.
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 14, children: charts),
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
            padding: EdgeInsets.zero,
            child: Column(
              children: history.indexed
                  .map((e) => CheckInHistoryRow(
                        checkIn: e.$2,
                        first: e.$1 == 0,
                        onTap: () => DayRecordsScreen.open(context, e.$2),
                      ))
                  .toList(),
            ),
          ),
        const SizedBox(height: 24),
      ]),
    );
  }

  static double _avg(List<double> xs) => xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;

  static String _fmtWeight(double kg) => kg == kg.roundToDouble() ? '${kg.round()}' : kg.toStringAsFixed(1);
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
    this.showAvg = true,
  });
  final String title;
  final String value;
  final String unit;
  final List<ChartSeries> series;
  final List<(String, Color)> legend;
  final EdgeInsetsGeometry? margin;
  final bool showAvg;

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
            if (showAvg) Text('${s.strings.checkin.avg} ', style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
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

/// Trends metric selector — trigger + checkbox panel (replaces the chip row).
class _MetricsDropdown extends StatelessWidget {
  const _MetricsDropdown({required this.visible, required this.onToggle});

  final Set<_TrendMetric> visible;
  final ValueChanged<_TrendMetric> onToggle;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final all = _TrendMetric.values.length;
    final label = visible.length == all
        ? s.strings.checkin.trend_all_metrics
        : s.strings.checkin.trend_n_metrics('${visible.length}');

    return MenuAnchor(
      alignmentOffset: const Offset(0, 6),
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(Colors.white),
        elevation: const WidgetStatePropertyAll(6),
        shadowColor: const WidgetStatePropertyAll(Color(0x2414202B)),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
        minimumSize: const WidgetStatePropertyAll(Size(210, 0)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(T.rLg),
          side: const BorderSide(color: T.border),
        )),
      ),
      builder: (context, controller, _) => Pressable(
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
        scale: 0.99,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(T.rMd),
            border: Border.all(color: T.border, width: 1.5),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(LucideIcons.slidersHorizontal, size: 15, color: T.fg3),
            const SizedBox(width: 8),
            Text(label, style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
            const SizedBox(width: 8),
            AnimatedRotation(
              turns: controller.isOpen ? 0.5 : 0,
              duration: Motion.base,
              curve: Motion.easeOut,
              child: const Icon(LucideIcons.chevronDown, size: 15, color: T.fg3),
            ),
          ]),
        ),
      ),
      menuChildren: [
        for (final m in _TrendMetric.values)
          MenuItemButton(
            closeOnActivate: false,
            onPressed: () => onToggle(m),
            style: ButtonStyle(
              padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
              minimumSize: const WidgetStatePropertyAll(Size(198, 0)),
              shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(T.rSm))),
            ),
            child: Row(children: [
              // 18px checkbox: accent fill + white tick when on, else outline.
              Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: visible.contains(m) ? s.accent.main : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                  border: visible.contains(m) ? null : Border.all(color: T.borderStrong, width: 1.5),
                ),
                child: visible.contains(m) ? const Icon(LucideIcons.check, size: 12, color: Colors.white) : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child:
                    Text(m.label(s), style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w500, color: T.fg1)),
              ),
            ]),
          ),
      ],
    );
  }
}
