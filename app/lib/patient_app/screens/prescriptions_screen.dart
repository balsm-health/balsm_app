import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_state.dart';
import '../data.dart';
import '../kit.dart';
import '../responsive.dart';
import '../tokens.dart';
import '../widgets/badges.dart';

/// Prescriptions sub-screen (reached from Meds). Active / expired list.
class PrescriptionsScreen extends StatefulWidget {
  const PrescriptionsScreen({super.key});
  @override
  State<PrescriptionsScreen> createState() => _PrescriptionsScreenState();
}

class _PrescriptionsScreenState extends State<PrescriptionsScreen> {
  String filter = 'active';
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final shown = kPrescriptions.where((r) => r.status == filter).toList();
    return ContentColumn(maxWidth: 720, child: Column(children: [
      const PadTop(),
      AppBarRow(
        leading: RoundBtn(icon: LucideIcons.arrowLeft, onTap: () => s.setTab('meds')),
        children: [Expanded(child: Text(s.t('prescriptions'), style: Typo.heading(ar: s.rtl).copyWith(fontSize: FS.xl)))],
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Row(children: [
          for (final f in const ['active', 'expired'])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Pressable(
                onTap: () => setState(() => filter = f),
                scale: 0.97,
                child: AnimatedContainer(
                  duration: Motion.base,
                  curve: Motion.easeOut,
                  height: 36, padding: const EdgeInsets.symmetric(horizontal: 16), alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: filter == f ? s.accent.bg : Colors.white,
                    borderRadius: BorderRadius.circular(T.rPill),
                    border: Border.all(color: filter == f ? s.accent.main : T.border, width: 1.5),
                  ),
                  child: Text(s.t(f == 'active' ? 'rx_active' : 'rx_expired'),
                      style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: filter == f ? s.accent.d : T.fg2)),
                ),
              ),
            ),
        ]),
      ),
      Expanded(child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [for (final r in shown) Padding(padding: const EdgeInsets.only(bottom: 12), child: _RxCard(rx: r))],
      )),
    ]));
  }
}

class _RxCard extends StatelessWidget {
  const _RxCard({required this.rx});
  final Prescription rx;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final doc = doctorById(rx.doctorId);
    final active = rx.status == 'active';
    return PCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (doc != null) DoctorAvatar(doctor: doc, size: 42),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(doc?.name.of(s.lang) ?? '', style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg1)),
            Text(rx.date.of(s.lang), style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
          ])),
          Pill(s.t(active ? 'rx_active' : 'rx_expired'), kind: active ? PillKind.success : PillKind.neutral, ar: s.rtl),
        ]),
        const SizedBox(height: 14),
        Container(height: 1, color: T.ink100),
        const SizedBox(height: 12),
        for (final m in rx.meds)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Container(width: 34, height: 34, alignment: Alignment.center, decoration: BoxDecoration(color: T.petalBlue50, borderRadius: BorderRadius.circular(T.rSm)), child: const Icon(LucideIcons.pill, size: 17, color: T.petalBlue)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m.name.of(s.lang), style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
                Text(m.dose.of(s.lang), style: Typo.meta(ar: s.rtl)),
              ])),
            ]),
          ),
        const SizedBox(height: 4),
        Row(children: [
          const Icon(LucideIcons.calendarClock, size: 14, color: T.fg3),
          const SizedBox(width: 6),
          Text('${s.t('rx_valid_until')} ${rx.validUntil.of(s.lang)}', style: Typo.meta(ar: s.rtl)),
        ]),
        if (active) ...[
          const SizedBox(height: 14),
          PButton(s.t('rx_show'), icon: LucideIcons.qrCode, variant: BtnVariant.soft, block: true, accent: s.accent, ar: s.rtl),
        ],
      ]),
    );
  }
}
