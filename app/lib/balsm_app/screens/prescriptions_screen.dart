import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:prescriptions/prescriptions.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../app_state.dart';
import '../kit.dart';
import '../responsive.dart';
import '../tokens.dart';
import 'appointments_screen.dart' show formatAppointmentDate;

/// Prescriptions the patient holds — grouped active / expired.
///
/// Reached from the medications tab. Patient-entered on-device; the reference
/// code is rendered as a QR for a pharmacy to scan.
class PrescriptionsScreen extends ConsumerWidget {
  const PrescriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final all = ref.watch(prescriptionListProvider).valueOrNull ?? const <Prescription>[];
    final now = DateTime.now();
    final active = all.where((r) => r.isActive(now)).toList();
    final expired = all.where((r) => !r.isActive(now)).toList();

    return ContentColumn(
      maxWidth: 720,
      child: ListView(padding: EdgeInsets.zero, children: [
        const PadTop(),
        AppBarRow(children: [
          RoundBtn(icon: backArrow(context), onTap: () => s.setTab('meds')),
          const SizedBox(width: 12),
          Expanded(child: Text(s.strings.records.prescriptions, style: Typo.heading(ar: s.rtl))),
        ]),
        if (all.isEmpty)
          PCard(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
            child: Column(children: [
              const Icon(LucideIcons.fileText, size: 36, color: T.fg4),
              const SizedBox(height: 14),
              Text(s.strings.records.prescriptions,
                  textAlign: TextAlign.center,
                  style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg2)),
            ]),
          ),
        if (active.isNotEmpty) ...[
          RowHead(s.strings.meds.rx_active, ar: s.rtl),
          for (final rx in active) _RxCard(rx: rx, dim: false),
        ],
        if (expired.isNotEmpty) ...[
          RowHead(s.strings.meds.rx_expired, ar: s.rtl),
          for (final rx in expired) _RxCard(rx: rx, dim: true),
        ],
        const SizedBox(height: 28),
      ]),
    );
  }
}

class _RxCard extends StatelessWidget {
  const _RxCard({required this.rx, required this.dim});
  final Prescription rx;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final active = !dim;
    return Opacity(
      opacity: dim ? 0.7 : 1,
      child: PCard(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        padding: const EdgeInsets.all(14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PrescriptionDetailScreen(rx: rx)),
        ),
        child: Row(children: [
          Avatar(initials: _initials(rx.clinician), color: T.petalAqua, size: 44, fontSize: FS.md, ar: s.rtl),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(rx.clinician,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
              const SizedBox(height: 2),
              Text('${_itemCount(s, rx.items.length)} · ${formatAppointmentDate(rx.issuedAt, s)}',
                  style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
            ]),
          ),
          const SizedBox(width: 8),
          Pill(active ? s.strings.meds.rx_active : s.strings.meds.rx_expired,
              kind: active ? PillKind.success : PillKind.neutral, ar: s.rtl),
          const SizedBox(width: 6),
          Chevron(rtl: s.rtl),
        ]),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }
}

/// One prescription in full, with the scannable reference.
class PrescriptionDetailScreen extends StatelessWidget {
  const PrescriptionDetailScreen({super.key, required this.rx});
  final Prescription rx;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final active = rx.isActive();
    return Scaffold(
      backgroundColor: Colors.white,
      body: ContentColumn(
        maxWidth: 720,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const PadTop(),
          AppBarRow(children: [
            RoundBtn(icon: backArrow(context), onTap: () => Navigator.of(context).pop()),
            const Spacer(),
            Pill(active ? s.strings.meds.rx_active : s.strings.meds.rx_expired,
                kind: active ? PillKind.success : PillKind.neutral, ar: s.rtl),
          ]),
          Expanded(
            child: ListView(padding: EdgeInsets.zero, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Avatar(
                        initials: _RxCard._initials(rx.clinician),
                        color: T.petalAqua,
                        size: 50,
                        fontSize: FS.lg,
                        ar: s.rtl),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(rx.clinician,
                            style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg1)),
                        if (rx.specialty != null && rx.specialty!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(rx.specialty!, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
                          ),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  Row(children: [
                    _Fact(label: s.strings.meds.rx_issued, value: formatAppointmentDate(rx.issuedAt, s)),
                    const SizedBox(width: 24),
                    if (rx.validUntil != null)
                      _Fact(
                        label: s.strings.meds.rx_valid_until,
                        value: formatAppointmentDate(rx.validUntil!, s),
                        color: active ? T.fg1 : T.danger,
                      ),
                  ]),
                ]),
              ),
              if (active && (rx.reference ?? '').isNotEmpty) _QrBlock(reference: rx.reference!),
              RowHead(s.strings.meds.medications, ar: s.rtl),
              PCard(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(children: [
                  for (final (i, item) in rx.items.indexed) _ItemRow(item: item, first: i == 0),
                ]),
              ),
              if (active && (rx.reference ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: PButton(s.strings.meds.rx_show,
                      icon: LucideIcons.qrCode,
                      variant: BtnVariant.primary,
                      large: true,
                      block: true,
                      accent: s.accent,
                      ar: s.rtl,
                      onTap: () => _showFullScreenQr(context, s, rx.reference!)),
                ),
              const SizedBox(height: 28),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Blows the dispensing code up to fill the screen so a pharmacy scanner can
/// read it across a counter. Nothing leaves the device — same local reference.
void _showFullScreenQr(BuildContext context, PatientAppState s, String reference) {
  showDialog<void>(
    context: context,
    barrierColor: const Color(0xF2FFFFFF),
    builder: (ctx) => Directionality(
      textDirection: s.dir,
      child: GestureDetector(
        onTap: () => Navigator.pop(ctx),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(s.strings.meds.rx_scan.toUpperCase(), style: Typo.eyebrow(T.fg3, ar: s.rtl)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration:
                  BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(T.rXl), boxShadow: T.shadowMd),
              child: QrImageView(
                data: reference,
                size: 260,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: T.ink900),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: T.ink900,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(reference,
                textDirection: TextDirection.ltr,
                style: Typo.num(size: FS.md, color: T.fg2).copyWith(letterSpacing: 0.8)),
          ]),
        ),
      ),
    ),
  );
}

/// `{n} medications` / `1 medication`, per the design's list subtitle.
String _itemCount(PatientAppState s, int n) => n == 1 ? s.strings.meds.rx_med_one : s.strings.meds.rx_meds_n('$n');

/// `.card` on cream with the QR and its reference underneath.
class _QrBlock extends StatelessWidget {
  const _QrBlock({required this.reference});
  final String reference;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(color: T.cream100, borderRadius: BorderRadius.circular(T.rXl)),
      child: Column(children: [
        Text(s.strings.meds.rx_scan.toUpperCase(), style: Typo.eyebrow(T.fg3, ar: s.rtl)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(T.rLg),
            boxShadow: T.shadowSm,
          ),
          child: QrImageView(
            data: reference,
            size: 148,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: T.ink900),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: T.ink900,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(reference,
            textDirection: TextDirection.ltr, style: Typo.num(size: FS.sm, color: T.fg3).copyWith(letterSpacing: 0.8)),
      ]),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(), style: Typo.eyebrow(T.fg4, ar: s.rtl)),
      const SizedBox(height: 3),
      Text(value, style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: color ?? T.fg1)),
    ]);
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.first});
  final PrescribedItem item;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Container(
      decoration: BoxDecoration(border: first ? null : const Border(top: BorderSide(color: T.ink100))),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: T.petalBlue50, borderRadius: BorderRadius.circular(T.rMd)),
          child: const Icon(LucideIcons.pill, size: 20, color: T.petalBlue),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name, style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
            if (item.dose != null && item.dose!.isNotEmpty)
              Text(item.dose!, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
          ]),
        ),
      ]),
    );
  }
}
