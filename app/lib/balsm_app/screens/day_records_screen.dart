import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:self_report/self_report.dart';
import '../app_state.dart';
import '../kit.dart';
import '../responsive.dart';
import '../tokens.dart';
import '../widgets/mood_face.dart';
import 'checkin_shared.dart';

/// One check-in's readings — mood hero, metric rows, optional symptoms card.
///
/// Port of the Claude Design `DayRecordsScreen`. Times come from the single
/// [CheckIn.recordedAt]; the domain does not store per-metric clocks, so we
/// never invent them.
class DayRecordsScreen extends StatelessWidget {
  const DayRecordsScreen({super.key, required this.checkIn});
  final CheckIn checkIn;

  static Future<void> open(BuildContext context, CheckIn checkIn) {
    return Navigator.of(context).push(MaterialPageRoute(builder: (_) => DayRecordsScreen(checkIn: checkIn)));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final d = checkIn.recordedAt.toLocal();
    final v = checkIn.vitals;
    final glucose = v.glucoseFasting ?? v.glucosePostMeal ?? v.glucoseRandom;
    final time = MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(d));
    final mood = checkIn.mood;

    final rows = <_MetricRow>[
      if (v.systolic != null && v.diastolic != null)
        _MetricRow(
          icon: LucideIcons.activity,
          label: s.strings.profile.m_bp,
          value: '${v.systolic}/${v.diastolic}',
          unit: s.strings.checkin.unit_bp,
          color: T.petalViolet,
          bg: T.petalViolet50,
        ),
      if (glucose != null)
        _MetricRow(
          icon: LucideIcons.droplet,
          label: s.strings.profile.m_glucose,
          value: '$glucose',
          unit: s.strings.checkin.unit_glu,
          color: T.petalMint600,
          bg: T.petalMint50,
        ),
      if (v.spo2 != null)
        _MetricRow(
          icon: LucideIcons.wind,
          label: s.strings.profile.m_o2,
          value: '${v.spo2}',
          unit: s.strings.checkin.unit_spo2,
          color: T.petalBlue,
          bg: T.petalBlue50,
        ),
      if (v.weightKg != null)
        _MetricRow(
          icon: LucideIcons.scale,
          label: s.strings.profile.m_weight,
          value: _weight(v.weightKg!),
          unit: s.strings.checkin.unit_kg,
          color: T.petalBlue,
          bg: T.petalBlue50,
        ),
      _MetricRow(
        icon: LucideIcons.zap,
        label: s.strings.profile.m_pain,
        value: '${checkIn.painLevel.value}/10',
        unit: '',
        color: T.danger,
        bg: T.dangerBg,
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: ContentColumn(
        maxWidth: 720,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const PadTop(),
          AppBarRow(children: [
            RoundBtn(icon: backArrow(context), onTap: () => Navigator.of(context).pop()),
            const SizedBox(width: 12),
            Expanded(
              child: Text('${d.day} ${checkInMonthShort(s, d)}', style: Typo.heading(ar: s.rtl)),
            ),
          ]),
          Expanded(
            child: ListView(padding: EdgeInsets.zero, children: [
              if (mood != null)
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(T.rLg),
                    border: Border.all(color: s.accent.bg),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      stops: const [0.0, 0.65],
                      colors: [s.accent.bg, T.cream50],
                    ),
                  ),
                  child: Row(children: [
                    MoodFace(level: mood.score, size: 40, color: moodColors[mood.score - 1]),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(moodLabel(s, mood.score),
                            style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg1)),
                        Text(s.strings.profile.m_mood, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
                      ]),
                    ),
                    Row(children: [
                      const Icon(LucideIcons.clock, size: 13, color: T.fg3),
                      const SizedBox(width: 5),
                      Text(time, style: Typo.meta(ar: s.rtl)),
                    ]),
                  ]),
                ),
              PCard(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: EdgeInsets.zero,
                child: Column(
                  children: rows.indexed
                      .map((e) => _MetricLine(row: e.$2, last: e.$1 == rows.length - 1, time: time))
                      .toList(),
                ),
              ),
              if (checkIn.symptoms.isNotEmpty)
                PCard(
                  margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  child: Row(children: [
                    const IconSquare(LucideIcons.stethoscope,
                        bg: Color(0xFFFDF5DC), fg: Color(0xFF9A6E00), size: 38, iconSize: 19, radius: T.rMd),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.strings.checkin.symptoms_n('${checkIn.symptoms.length}'),
                            style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
                        const SizedBox(height: 2),
                        Row(children: [
                          const Icon(LucideIcons.clock, size: 12, color: T.fg3),
                          const SizedBox(width: 5),
                          Text(time, style: Typo.meta(ar: s.rtl)),
                        ]),
                      ]),
                    ),
                  ]),
                ),
              const SizedBox(height: 24),
            ]),
          ),
        ]),
      ),
    );
  }

  static String _weight(double kg) => kg == kg.roundToDouble() ? '${kg.round()}' : kg.toStringAsFixed(1);
}

class _MetricRow {
  const _MetricRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.bg,
  });
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;
  final Color bg;
}

class _MetricLine extends StatelessWidget {
  const _MetricLine({required this.row, required this.last, required this.time});
  final _MetricRow row;
  final bool last;
  final String time;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: T.ink50))),
      child: Row(children: [
        IconSquare(row.icon, bg: row.bg, fg: row.color, size: 42, iconSize: 20, radius: T.rMd),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(row.label, style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
            const SizedBox(height: 2),
            Row(children: [
              const Icon(LucideIcons.clock, size: 12, color: T.fg3),
              const SizedBox(width: 5),
              Text(time, style: Typo.meta(ar: s.rtl)),
            ]),
          ]),
        ),
        Text.rich(
          TextSpan(children: [
            TextSpan(text: row.value, style: Typo.num(size: FS.md, weight: FontWeight.w700, color: T.fg1)),
            if (row.unit.isNotEmpty)
              TextSpan(text: ' ${row.unit}', style: Typo.num(size: FS.xs, weight: FontWeight.w500, color: T.fg4)),
          ]),
        ),
      ]),
    );
  }
}
