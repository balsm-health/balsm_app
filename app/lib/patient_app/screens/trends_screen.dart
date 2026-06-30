import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_state.dart';
import '../data.dart';
import '../kit.dart';
import '../responsive.dart';
import '../tokens.dart';
import '../widgets/line_chart.dart';
import 'home_screen.dart' show HistoryRow;

/// Trends sub-screen (home.jsx TrendsScreen).
class TrendsScreen extends StatefulWidget {
  const TrendsScreen({super.key});
  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  String range = 'range_w';
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return ContentColumn(maxWidth: 720, child: ListView(padding: EdgeInsets.zero, children: [
      const PadTop(),
      AppBarRow(children: [
        RoundBtn(icon: LucideIcons.arrowLeft, onTap: () => s.setTab('home')),
        const SizedBox(width: 12),
        Expanded(child: Text(s.t('trends'), style: Typo.heading(ar: s.rtl).copyWith(fontSize: FS.xl))),
        _RangeTabs(value: range, onChange: (r) => setState(() => range = r)),
      ]),
      // BP chart
      PCard(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _ChartHead(title: s.t('m_bp'), avg: '131/84', unit: s.t('unit_bp')),
          const SizedBox(height: 6),
          LineChartView(rtl: s.rtl, series: const [
            ChartSeries(kTrendBpSys, T.petalViolet),
            ChartSeries(kTrendBpDia, T.petalBlue),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _Legend(color: T.petalViolet, label: s.t('sys')),
            const SizedBox(width: 16),
            _Legend(color: T.petalBlue, label: s.t('dia')),
          ]),
        ]),
      ),
      // Glucose chart
      PCard(
        margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _ChartHead(title: s.t('m_glucose'), avg: '144', unit: s.t('unit_glu')),
          const SizedBox(height: 6),
          LineChartView(rtl: s.rtl, series: const [ChartSeries(kTrendGlu, T.petalMint600)]),
        ]),
      ),
      RowHead(s.t('reports'), ar: s.rtl),
      PCard(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(children: [
          for (var i = 0; i < kHistory.length; i++) HistoryRow(h: kHistory[i], onTap: () {}, first: i == 0),
        ]),
      ),
      const SizedBox(height: 24),
    ]));
  }
}

class _ChartHead extends StatelessWidget {
  const _ChartHead({required this.title, required this.avg, required this.unit});
  final String title, avg, unit;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(title, style: Typo.subhead(ar: s.rtl).copyWith(fontSize: FS.md)),
      Row(children: [
        Text('${s.t('avg')} ', style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
        Text(avg, style: Typo.num(weight: FontWeight.w700, size: FS.sm)),
        Text(' $unit', style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
      ]),
    ]);
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label, style: Typo.meta(ar: s.rtl)),
    ]);
  }
}

class _RangeTabs extends StatelessWidget {
  const _RangeTabs({required this.value, required this.onChange});
  final String value;
  final ValueChanged<String> onChange;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (final r in const ['range_w', 'range_m', 'range_3m'])
        Pressable(
          onTap: () => onChange(r),
          scale: 0.95,
          // `.range-tabs button.on` — active bg animates over --dur-base.
          child: AnimatedContainer(
            duration: Motion.base,
            curve: Motion.easeOut,
            margin: const EdgeInsets.only(left: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: value == r ? T.ink100 : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(s.t(r), style: Typo.meta(ar: s.rtl).copyWith(
                fontWeight: FontWeight.w600, color: value == r ? T.fg1 : T.fg3)),
          ),
        ),
    ]);
  }
}
