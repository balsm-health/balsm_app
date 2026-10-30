import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:prescriptions/prescriptions.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../app_state.dart';
import '../routes.dart';
import '../kit.dart';
import '../responsive.dart';
import '../tokens.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/attachment_thumb.dart';
import '../widgets/delete_kit.dart';
import '../widgets/vault_file_viewer.dart';
import 'add_prescription_sheet.dart';

/// Prescriptions the patient holds — grouped active / expired.
///
/// Reached from the medications tab. Patient-entered on-device; the reference
/// code is rendered as a QR for a pharmacy to scan.
///
/// The patient's own prescriptions delete through the shared [DeleteKit]
/// (swipe, `⋮`, Select, or the detail page's bin). Clinic-issued ones are a
/// record of what a prescriber wrote and stay ([DeletePrescriptionUseCase]).
class PrescriptionsScreen extends ConsumerStatefulWidget {
  const PrescriptionsScreen({super.key});

  @override
  ConsumerState<PrescriptionsScreen> createState() => _PrescriptionsScreenState();
}

class _PrescriptionsScreenState extends ConsumerState<PrescriptionsScreen>
    with DeleteKit<PrescriptionsScreen, PrescriptionId> {
  /// Asks before deleting [rxs] (the patient's own); nothing changes on Cancel.
  void _askDelete(List<Prescription> rxs) {
    if (rxs.isEmpty) return;
    final s = AppScope.of(context);
    final m = s.strings.meds;
    final one = rxs.length == 1 ? rxs.single : null;
    final what = one != null ? _rxLabel(one) : m.rx_count(rxs.length);
    confirmDelete(
      title: s.strings.common.del_title(what),
      body: one != null ? m.rx_del_body_one : m.rx_del_body_n,
      done: what,
      onConfirmed: () async {
        final delete = ref.read(deletePrescriptionUseCaseProvider);
        for (final rx in rxs) {
          await delete(rx);
        }
      },
    );
  }

  Future<void> _openDetail(Prescription rx) async {
    final deleted =
        await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => PrescriptionDetailScreen(rx: rx)));
    if (deleted == true && mounted) showDeleted(_rxLabel(rx));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final all = ref.watch(prescriptionListProvider).valueOrNull ?? const <Prescription>[];
    final now = DateTime.now();
    final clinic = all.where((r) => !r.isSelf && r.isActive(now)).toList();
    final mine = all.where((r) => r.isSelf && r.isActive(now)).toList();
    final expired = all.where((r) => !r.isActive(now)).toList();
    final deletable = all.where((r) => r.isSelf).toList();

    Widget card(Prescription rx, {required bool dim}) {
      final plain = _RxCard(
        rx: rx,
        dim: dim,
        lead: rx.isSelf ? kitCheck(rx.id) : null,
        trail: rx.isSelf ? kitMore(label: _rxLabel(rx), onDelete: () => _askDelete([rx])) : null,
        onTap: selecting ? null : () => _openDetail(rx),
      );
      if (!rx.isSelf) return plain;
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        child: kitSwipe(
          item: rx.id,
          label: _rxLabel(rx),
          onDelete: () => _askDelete([rx]),
          radius: T.rLg,
          child: plain,
        ),
      );
    }

    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && selecting) endSelect();
      },
      child: ContentColumn(
        maxWidth: 720,
        child: Stack(children: [
          ListView(padding: EdgeInsets.zero, children: [
            const PadTop(),
            if (selecting)
              kitSelectAppBar(deletable.map((r) => r.id))
            else
              AppBarRow(children: [
                RoundBtn(
                    icon: backArrow(context),
                    semanticLabel: s.strings.common.a11y_back,
                    onTap: () => s.setTab(AppTab.meds)),
                const SizedBox(width: 12),
                Expanded(child: Text(s.strings.records.prescriptions, style: Typo.heading(ar: s.rtl))),
                if (deletable.isNotEmpty) ...[kitSelectButton(), const SizedBox(width: 8)],
                RoundBtn(
                  icon: LucideIcons.plus,
                  semanticLabel: s.strings.common.a11y_add,
                  onTap: () => showAddPrescription(context),
                ),
              ]),
            if (all.isEmpty)
              PCard(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(children: [
                  const Icon(LucideIcons.fileText, size: 36, color: T.fg4),
                  const SizedBox(height: 14),
                  Text(s.strings.meds.rx_empty,
                      textAlign: TextAlign.center,
                      style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg2)),
                  const SizedBox(height: 8),
                  Text(s.strings.meds.rx_empty_h, textAlign: TextAlign.center, style: Typo.meta(ar: s.rtl)),
                ]),
              ),
            if (clinic.isNotEmpty) ...[
              RowHead(s.strings.meds.rx_active, ar: s.rtl),
              for (final rx in clinic) card(rx, dim: false),
            ],
            if (mine.isNotEmpty) ...[
              RowHead(s.strings.meds.rx_my_prescriptions, ar: s.rtl),
              for (final rx in mine) card(rx, dim: false),
            ],
            if (expired.isNotEmpty) ...[
              RowHead(s.strings.meds.rx_expired, ar: s.rtl),
              for (final rx in expired) card(rx, dim: true),
            ],
            SizedBox(height: kitBottomRoom),
          ]),
          ...deleteKitOverlays(
            count: s.strings.meds.rx_count,
            onDeleteSelected: () => _askDelete(deletable.where((r) => selected.contains(r.id)).toList()),
          ),
        ]),
      ),
    );
  }
}

/// What a prescription is called in a delete prompt: its title, else the
/// prescriber's name.
String _rxLabel(Prescription rx) => rx.title ?? rx.clinician;

class _RxCard extends StatelessWidget {
  const _RxCard({required this.rx, required this.dim, this.lead, this.trail, this.onTap});
  final Prescription rx;
  final bool dim;

  /// Select's tick box and the `⋮`, on the patient's own prescriptions;
  /// those cards sit in a swipe row, which owns their margin.
  final Widget? lead;
  final Widget? trail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final active = !dim;
    return Opacity(
      opacity: dim ? 0.7 : 1,
      child: PCard(
        margin: lead == null ? const EdgeInsets.fromLTRB(20, 0, 20, 10) : null,
        padding: EdgeInsetsDirectional.fromSTEB(14, 14, trail == null ? 14 : 4, 14),
        onTap: onTap,
        child: Row(children: [
          if (lead != null) lead!,
          rx.isSelf
              ? Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: T.hueBlue50, shape: BoxShape.circle),
                  child: Icon(rx.attachmentPath != null ? LucideIcons.fileText : LucideIcons.pill,
                      size: 21, color: T.hueBlue),
                )
              : Avatar(initials: _initials(rx.clinician), color: T.hueAqua, size: 44, fontSize: FS.md, ar: s.rtl),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(rx.isSelf ? (rx.title ?? rx.clinician) : rx.clinician,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
              const SizedBox(height: 2),
              Text('${_itemCount(s, rx.items.length)} · ${_formatShortDate(rx.issuedAt, s)}',
                  style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
            ]),
          ),
          const SizedBox(width: 8),
          Pill(
            rx.isSelf ? s.strings.meds.rx_self_added : (active ? s.strings.meds.rx_active : s.strings.meds.rx_expired),
            kind: !rx.isSelf && active ? PillKind.success : PillKind.neutral,
            ar: s.rtl,
          ),
          const SizedBox(width: 6),
          trail ?? Chevron(rtl: s.rtl),
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
class PrescriptionDetailScreen extends ConsumerWidget {
  const PrescriptionDetailScreen({super.key, required this.rx});
  final Prescription rx;

  /// Deletion is domain policy (patient-entered rows only), so it goes through
  /// the use case rather than the data source. Reaching for the container off
  /// the BuildContext bypassed both the widget's own `ref` and that policy.
  /// Asks first (design delete-kit); pops `true` so the list confirms it.
  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final s = AppScope.of(context);
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0x6114202B),
      builder: (_) =>
          ConfirmDeleteDialog(title: s.strings.common.del_title(_rxLabel(rx)), body: s.strings.meds.rx_del_body_one),
    );
    if (ok != true) return;
    await ref.read(deletePrescriptionUseCaseProvider)(rx);
    if (context.mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final active = rx.isActive();
    return Scaffold(
      backgroundColor: Colors.white,
      body: ContentColumn(
        maxWidth: 720,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const PadTop(),
          AppBarRow(children: [
            RoundBtn(
                icon: backArrow(context),
                semanticLabel: s.strings.common.a11y_back,
                onTap: () => Navigator.of(context).pop()),
            const Spacer(),
            if (rx.isSelf)
              RoundBtn(
                icon: LucideIcons.trash2,
                semanticLabel: s.strings.common.a11y_delete,
                ghost: true,
                iconSize: 18,
                fg: T.danger,
                onTap: () => _delete(context, ref),
              )
            else
              Pill(active ? s.strings.meds.rx_active : s.strings.meds.rx_expired,
                  kind: active ? PillKind.success : PillKind.neutral, ar: s.rtl),
          ]),
          Expanded(
            child: ListView(padding: EdgeInsets.zero, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    rx.isSelf
                        ? Container(
                            width: 50,
                            height: 50,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(color: T.hueBlue50, shape: BoxShape.circle),
                            child: const Icon(LucideIcons.user, size: 22, color: T.hueBlue),
                          )
                        : Avatar(
                            initials: _RxCard._initials(rx.clinician),
                            color: T.hueAqua,
                            size: 50,
                            fontSize: FS.lg,
                            ar: s.rtl),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(rx.isSelf ? (rx.title ?? rx.clinician) : rx.clinician,
                            style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg1)),
                        if (rx.isSelf && rx.clinician != rx.title && rx.clinician.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text('${s.strings.meds.rx_prescribed_by} ${rx.clinician}',
                                style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
                          ),
                        if (!rx.isSelf && rx.specialty != null && rx.specialty!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(rx.specialty!, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
                          ),
                        if (rx.isSelf)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Pill(s.strings.meds.rx_self_added, kind: PillKind.neutral, ar: s.rtl),
                          ),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  Row(children: [
                    _Fact(label: s.strings.meds.rx_issued, value: _formatShortDate(rx.issuedAt, s)),
                    const SizedBox(width: 24),
                    if (rx.validUntil != null)
                      _Fact(
                        label: s.strings.meds.rx_valid_until,
                        value: _formatShortDate(rx.validUntil!, s),
                        color: active ? T.fg1 : T.danger,
                      ),
                  ]),
                ]),
              ),
              if (rx.isSelf)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: BoxDecoration(color: T.cream100, borderRadius: BorderRadius.circular(T.rMd)),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(LucideIcons.info, size: 16, color: T.fg3),
                      const SizedBox(width: 10),
                      Expanded(
                          child:
                              Text(s.strings.meds.rx_self_note, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3))),
                    ]),
                  ),
                ),
              if (rx.isSelf && rx.attachmentPath != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: rx.attachmentKind == 'image'
                      ? VaultAttachmentThumb(path: rx.attachmentPath!, title: rx.title, height: 240)
                      : _LinkAttach(path: rx.attachmentPath!, kind: rx.attachmentKind ?? 'url', title: rx.title),
                ),
              if (active && !rx.isSelf && (rx.reference ?? '').isNotEmpty) _QrBlock(reference: rx.reference!),
              if (rx.items.isNotEmpty) ...[
                RowHead(s.strings.meds.medications, ar: s.rtl),
                PCard(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(children: [
                    for (final (i, item) in rx.items.indexed) _ItemRow(item: item, first: i == 0),
                  ]),
                ),
              ],
              if (active && !rx.isSelf && (rx.reference ?? '').isNotEmpty)
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

class _LinkAttach extends StatelessWidget {
  const _LinkAttach({required this.path, required this.kind, this.title});
  final String path;
  final String kind;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final isPdf = kind == 'pdf';
    // PDF: decrypt-in-memory viewer (bytes never touch disk). Link: browser.
    return Pressable(
      onTap: () {
        if (isPdf) {
          VaultFileViewer.open(context, path: path, title: title);
        } else {
          launchUrl(Uri.parse(path), mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(T.rLg),
          border: Border.all(color: T.border),
        ),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: T.hueViolet50, borderRadius: BorderRadius.circular(T.rMd)),
            child: Icon(isPdf ? LucideIcons.fileText : LucideIcons.link, size: 20, color: T.hueViolet),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(path,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
              Text(isPdf ? 'PDF' : 'Link', style: Typo.meta(ar: s.rtl)),
            ]),
          ),
          Icon(isPdf ? LucideIcons.eye : LucideIcons.externalLink, size: 16, color: T.fg4),
        ]),
      ),
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
          decoration: BoxDecoration(color: T.hueBlue50, borderRadius: BorderRadius.circular(T.rMd)),
          child: const Icon(LucideIcons.pill, size: 20, color: T.hueBlue),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name, style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
            if (item.dose != null && item.dose!.isNotEmpty)
              Text(item.dose!, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
            if (item.notes != null && item.notes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(item.notes!, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
              ),
          ]),
        ),
      ]),
    );
  }
}

/// `dd MMM yyyy` in the active locale, via the i69n `settings.cal_months`
/// bundle the date pickers already use (CODING_STANDARDS: no inline bilingual
/// ternaries). Moved here when the appointments screen was removed — this is
/// the only remaining caller.
String _formatShortDate(DateTime d, PatientAppState s) {
  final months = s.strings.settings.cal_months.split('|');
  final l = d.toLocal();
  return '${l.day.toString().padLeft(2, '0')} ${months[l.month - 1]} ${l.year}';
}
