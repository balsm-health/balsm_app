import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_state.dart';
import '../data.dart';
import '../kit.dart';
import '../responsive.dart';
import '../tokens.dart';

/// Medications tab (home.jsx MedsScreen).
class MedsScreen extends StatelessWidget {
  const MedsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final activeRx = kPrescriptions.where((r) => r.status == 'active').length;
    final groups = [
      ('morning', LucideIcons.sunrise, kMeds.where((m) => m.when == 'morning').toList()),
      ('evening', LucideIcons.moon, kMeds.where((m) => m.when == 'evening').toList()),
    ];
    return ContentColumn(maxWidth: 720, child: ListView(padding: EdgeInsets.zero, children: [
      const PadTop(),
      AppBarRow(children: [
        Expanded(child: Text(s.t('medications'), style: Typo.heading(ar: s.rtl).copyWith(fontSize: FS.xl))),
      ]),

      // Prescriptions link
      PCard(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        onTap: () => s.setTab('rx'),
        child: Row(children: [
          const IconSquare(LucideIcons.fileText, bg: T.petalViolet50, fg: T.petalViolet, size: 34, iconSize: 19, radius: T.rSm),
          const SizedBox(width: 14),
          Expanded(child: Text(s.t('prescriptions'),
              style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w500, color: T.fg1))),
          Pill('$activeRx ${s.t('rx_active').toLowerCase()}', kind: PillKind.success, ar: s.rtl),
          const SizedBox(width: 8),
          Chevron(rtl: s.rtl),
        ]),
      ),

      // Adherence
      PCard(
        margin: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        padding: const EdgeInsets.all(18),
        child: Row(children: [
          RingProgress(progress: 0.92, color: T.petalMint, label: '92%',
              labelStyle: Typo.num(size: FS.sm, weight: FontWeight.w800)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('92%', style: Typo.num(size: FS.md, weight: FontWeight.w700)),
                Text(' · ${s.t('adherence')}', style: Typo.subhead(ar: s.rtl).copyWith(fontSize: FS.md)),
              ]),
              const SizedBox(height: 6),
              Pill(s.t('on_track'), kind: PillKind.success, ar: s.rtl),
            ]),
          ),
        ]),
      ),

      for (final (key, icon, meds) in groups) ...[
        RowHead.icon(s.t(key), icon: icon, ar: s.rtl),
        PCard(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(children: [
            for (var i = 0; i < meds.length; i++)
              _MedListRow(med: meds[i], first: i == 0),
          ]),
        ),
      ],
      const SizedBox(height: 24),
    ]));
  }
}

class _MedListRow extends StatelessWidget {
  const _MedListRow({required this.med, required this.first});
  final Med med;
  final bool first;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final tone = medTone(med.tone);
    final taken = med.id == 'metformin';
    return Container(
      decoration: BoxDecoration(border: first ? null : const Border(top: BorderSide(color: T.ink100))),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(children: [
        Container(width: 42, height: 42, alignment: Alignment.center,
            decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(T.rMd)),
            child: Icon(med.icon, size: 21, color: tone.fg)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(med.name.of(s.lang), style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
          Text(med.dose.of(s.lang), style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
        ])),
        Pill(taken ? s.t('taken') : s.t('due'), kind: taken ? PillKind.success : PillKind.neutral, ar: s.rtl),
      ]),
    );
  }
}
