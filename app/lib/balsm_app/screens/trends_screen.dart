import 'package:family/family.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:self_report/self_report.dart';
import '../app_state.dart';
import '../routes.dart';
import '../kit.dart';
import '../responsive.dart';
import '../tokens.dart';
import '../widgets/line_chart.dart';
import 'checkin_shared.dart';
import 'day_records_screen.dart';
import '../storage_target.dart';
import '../widgets/data_loc_pill.dart';
import 'family/family_kit.dart';
import 'family/profile_bar.dart';
import 'trend_series.dart';

/// How far back the charts look.
enum TrendRange { week, month, quarter }

extension on TrendMetric {
  String label(PatientAppState s) => switch (this) {
        TrendMetric.bp => s.strings.profile.m_bp,
        TrendMetric.glucose => s.strings.profile.m_glucose,
        TrendMetric.pain => s.strings.profile.m_pain,
        TrendMetric.weight => s.strings.profile.m_weight,
        TrendMetric.height => s.strings.profile.pd_height,
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

/// Opens family [member]'s Trends (mother-child.jsx `MCTrendsScreen`).
Future<void> openMemberTrends(BuildContext context, FamilyMember member) =>
    pushFamilyScreen<void>(context, (_) => TrendsScreen(member: member));

/// Trends — vitals over time plus the check-in history list.
///
/// Reads real on-device check-ins; every series is derived from what the
/// patient actually logged, so a metric with no readings hides its card rather
/// than drawing an empty axis. Filter chips match the Claude Design TrendsScreen.
///
/// With [member] it is that family member's Trends, pushed from their
/// screen: the same layout drawn from their own check-ins and growth entries
/// (height joins the metrics), the profile bar under the title, and only the
/// metrics they have in the picker.
class TrendsScreen extends ConsumerStatefulWidget {
  const TrendsScreen({super.key, this.member});
  final FamilyMember? member;

  @override
  ConsumerState<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends ConsumerState<TrendsScreen> {
  /// The account holder's own Trends offers these metrics whether or not
  /// they hold readings.
  static const _selfMetrics = [TrendMetric.bp, TrendMetric.glucose, TrendMetric.pain, TrendMetric.weight];

  TrendRange _range = TrendRange.week;
  final _hidden = <TrendMetric>{};

  void _toggle(TrendMetric m, List<TrendMetric> offered) {
    setState(() {
      if (_hidden.contains(m)) {
        _hidden.remove(m);
      } else if (offered.where((x) => !_hidden.contains(x)).length > 1) {
        _hidden.add(m);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final member = widget.member;
    final history = member == null
        ? ref.watch(checkInHistoryProvider).valueOrNull ?? const <CheckIn>[]
        : ref.watch(profileCheckInsProvider(member.id)).valueOrNull ?? const <CheckIn>[];
    final growth = member == null
        ? const <GrowthEntry>[]
        : ref.watch(growthEntriesProvider(member.id)).valueOrNull ?? const <GrowthEntry>[];

    final all = trendSeries(history, growth: growth);
    final offered = member == null ? _selfMetrics : all.keys.toList();
    final cutoff = DateTime.now().subtract(Duration(days: _range.days));
    List<TrendPoint> inRange(TrendMetric m) =>
        _hidden.contains(m) ? const [] : (all[m] ?? const <TrendPoint>[]).where((p) => p.at.isAfter(cutoff)).toList();

    final bp = inRange(TrendMetric.bp);
    final sys = bp.map((p) => p.value).toList();
    final dia = bp.map((p) => p.value2!).toList();
    final glucose = inRange(TrendMetric.glucose).map((p) => p.value).toList();
    final pain = inRange(TrendMetric.pain).map((p) => p.value).toList();
    final weight = inRange(TrendMetric.weight).map((p) => p.value).toList();
    final height = inRange(TrendMetric.height).map((p) => p.value).toList();

    // Every metric that can appear is one line of this literal: switched on and
    // holding readings. Spacing between cards is applied where they are laid
    // out, so nothing here depends on how many came before it.
    const chartMargin = EdgeInsets.fromLTRB(20, 0, 20, 0);
    final charts = <Widget>[
      if (sys.isNotEmpty)
        _ChartCard(
          title: s.strings.profile.m_bp,
          value: '${_avg(sys).round()}/${_avg(dia).round()}',
          unit: s.strings.checkin.unit_bp,
          series: [ChartSeries(sys, T.hueViolet), ChartSeries(dia, T.hueBlue)],
          legend: [(s.strings.checkin.sys, T.hueViolet), (s.strings.checkin.dia, T.hueBlue)],
          margin: chartMargin,
        ),
      if (glucose.isNotEmpty)
        _ChartCard(
          title: s.strings.profile.m_glucose,
          value: _avg(glucose).round().toString(),
          unit: s.strings.checkin.unit_glu,
          series: [ChartSeries(glucose, T.hueMint600)],
          margin: chartMargin,
        ),
      if (pain.isNotEmpty)
        _ChartCard(
          title: s.strings.profile.m_pain,
          // "/10" belongs to the number: as a separate RTL unit its slash
          // flipped to "10/ 6.0".
          value: '${_avg(pain).toStringAsFixed(1)}/10',
          unit: '',
          series: [ChartSeries(pain, T.danger)],
          margin: chartMargin,
        ),
      if (weight.isNotEmpty)
        _ChartCard(
          title: s.strings.profile.m_weight,
          value: _fmtMeasure(weight.last),
          unit: s.strings.checkin.unit_kg,
          series: [ChartSeries(weight, T.hueBlue)],
          margin: chartMargin,
          showAvg: false,
        ),
      if (height.isNotEmpty)
        _ChartCard(
          title: s.strings.profile.pd_height,
          value: _fmtMeasure(height.last),
          unit: s.strings.profile.pd_cm,
          series: [ChartSeries(height, T.hueEmerald)],
          margin: chartMargin,
          showAvg: false,
        ),
    ];

    final list = ListView(padding: EdgeInsets.zero, children: [
      const PadTop(),
      AppBarRow(children: [
        RoundBtn(
          icon: backArrow(context),
          semanticLabel: s.strings.common.a11y_back,
          onTap: member == null ? () => s.setTab(AppTab.home) : () => Navigator.maybePop(context),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(s.strings.checkin.trends, style: Typo.heading(ar: s.rtl))),
        const DataLocPill(category: DataCategory.vitals),
      ]),
      if (member != null) const Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 14), child: ProfileBar()),
      // Range and metric filter share one row under the title: the tabs keep
      // their intrinsic width and the dropdown takes what is left. Putting
      // either beside the title squeezed the heading onto two lines, worst
      // in Arabic where "الرسوم البيانية" is long.
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: Row(children: [
          _RangeTabs(value: _range, onChange: (r) => setState(() => _range = r)),
          const SizedBox(width: 8),
          // Metric filter — a dropdown selector (the design replaced the
          // chip row with one): trigger summarising the selection, opening
          // a checkbox panel that closes on an outside tap.
          if (offered.isNotEmpty)
            Expanded(
              child: _MetricsDropdown(
                offered: offered,
                hidden: _hidden,
                onToggle: (m) => _toggle(m, offered),
              ),
            ),
        ]),
      ),
      if (charts.isEmpty)
        member == null ? _NoReadings(range: _range) : _NoMemberData(member: member)
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
            Text(member == null ? s.strings.checkin.no_checkins : s.strings.family.trends_nothing(member.shortName),
                textAlign: TextAlign.center,
                style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg2)),
          ]),
        )
      else
        PCard(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: EdgeInsets.zero,
          child: Column(
            children: groupCheckInsByDay(history)
                .indexed
                .map((e) => CheckInDayRow(
                      day: e.$2,
                      first: e.$1 == 0,
                      onTap: () => DayRecordsScreen.open(context, e.$2),
                    ))
                .toList(),
          ),
        ),
      const SizedBox(height: 24),
    ]);
    final body = ContentColumn(maxWidth: 720, child: list);
    return member == null ? body : Scaffold(backgroundColor: Colors.white, body: body);
  }

  static double _avg(List<double> xs) => xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;

  static String _fmtMeasure(double v) => v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);
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
            if (unit.isNotEmpty) Text(' $unit', style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
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

/// A family member with nothing to chart in the range.
class _NoMemberData extends StatelessWidget {
  const _NoMemberData({required this.member});
  final FamilyMember member;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final f = s.strings.family;
    return PCard(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Column(children: [
        const IconSquare(LucideIcons.trendingUp, bg: T.hueBlue50, fg: T.hueBlue, size: 52, iconSize: 24, radius: 16),
        const SizedBox(height: 10),
        Text(f.trends_empty_t,
            textAlign: TextAlign.center,
            style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg1)),
        const SizedBox(height: 4),
        Text(f.trends_empty_b(member.shortName, s.gender), textAlign: TextAlign.center, style: Typo.bodySm(ar: s.rtl)),
      ]),
    );
  }
}

/// Trends metric selector — trigger + checkbox panel (replaces the chip row).
class _MetricsDropdown extends StatelessWidget {
  const _MetricsDropdown({required this.offered, required this.hidden, required this.onToggle});

  final List<TrendMetric> offered;
  final Set<TrendMetric> hidden;
  final ValueChanged<TrendMetric> onToggle;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final shown = offered.where((m) => !hidden.contains(m)).length;
    final label =
        shown == offered.length ? s.strings.checkin.trend_all_metrics : s.strings.checkin.trend_n_metrics('$shown');

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
          // Fills the row (`width: 100%` in the design) rather than shrink-
          // wrapping, so the tabs beside it keep a stable width.
          child: Row(children: [
            const Icon(LucideIcons.slidersHorizontal, size: 15, color: T.fg3),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1),
              ),
            ),
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
        for (final m in offered)
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
                  color: !hidden.contains(m) ? s.accent.main : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                  border: !hidden.contains(m) ? null : Border.all(color: T.borderStrong, width: 1.5),
                ),
                child: !hidden.contains(m) ? const Icon(LucideIcons.check, size: 12, color: Colors.white) : null,
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
