import 'package:core/core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:medications/medications.dart';
import 'package:prescriptions/prescriptions.dart';
import '../app_state.dart';
import '../i18n/strings.i69n.dart';
import '../kit.dart';
import '../tokens.dart';
import '../widgets/date_time_row.dart';
import '../widgets/med_plan_form.dart';
import '../widgets/photo_attach.dart';

Future<void> showAddPrescription(BuildContext context) => showAppSheet<void>(
      context,
      size: SheetSize.lg,
      builder: (_) => const AddPrescriptionSheet(),
    );

class AddPrescriptionSheet extends ConsumerStatefulWidget {
  const AddPrescriptionSheet({super.key});

  @override
  ConsumerState<AddPrescriptionSheet> createState() => _AddPrescriptionSheetState();
}

class _AddPrescriptionSheetState extends ConsumerState<AddPrescriptionSheet> {
  final _title = TextEditingController();
  final _doctor = TextEditingController();
  final _url = TextEditingController();
  final _meds = [MedPlanDraft()];
  DateTime _issued = DateTime.now();
  DateTime? _expiry;
  PickedAttach? _attach;
  bool _saving = false;
  bool _done = false;

  @override
  void dispose() {
    _title.dispose();
    _doctor.dispose();
    _url.dispose();
    for (final m in _meds) {
      m.dispose();
    }
    super.dispose();
  }

  bool get _ready {
    final hasFile = _attach != null || _url.text.trim().isNotEmpty;
    final hasMeds = _meds.any((m) => m.isNamed);
    return hasFile || hasMeds;
  }

  Future<void> _save() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null || _saving || !_ready) return;
    setState(() => _saving = true);
    final s = AppScope.of(context);
    final m = s.strings.meds;
    final named = _meds.where((d) => d.isNamed).toList();
    final items = [
      for (final d in named)
        PrescribedItem(
          name: d.name.text.trim(),
          dose: d.summary(m),
          notes: d.notes.text.trim().isEmpty ? null : d.notes.text.trim(),
        ),
    ];
    String? attachPath;
    String? attachKind;
    if (_attach?.bytes != null) {
      final id = 'rx-${DateTime.now().microsecondsSinceEpoch}';
      final ext = _attach!.kind == 'pdf' ? 'pdf' : 'jpg';
      attachPath = await ref.read(userFileStoreProvider).save('$id.$ext', _attach!.bytes!);
      attachKind = _attach!.kind;
    } else if (_url.text.trim().isNotEmpty) {
      attachPath = _url.text.trim();
      attachKind = 'url';
    }
    final title = _title.text.trim().isEmpty ? m.rx_default_title : _title.text.trim();
    final doctor = _doctor.text.trim();
    final id = PrescriptionId.value('rx-${DateTime.now().microsecondsSinceEpoch}');
    await ref.read(prescriptionsDataSourceProvider).put(
          id,
          Prescription(
            id: id,
            userId: userId,
            clinician: doctor.isEmpty ? title : doctor,
            title: title,
            source: 'self',
            attachmentPath: attachPath,
            attachmentKind: attachKind,
            items: items,
            issuedAt: _issued,
            validUntil: _expiry,
            createdAt: DateTime.now(),
          ),
        );
    // Each med also joins the Meds tab's daily list, on its own schedule.
    final addMedication = ref.read(addMedicationUseCaseProvider(userId));
    for (final d in named) {
      await addMedication.call(d.toMedication(userId));
    }
    ref
      ..invalidate(todayDosesProvider)
      ..invalidate(medicationListProvider);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _done = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final m = s.strings.meds;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(T.rXl)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(children: [
            if (!_done)
              const Center(
                child: SheetGrab(),
              ),
            if (!_done) const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child:
                    Text(_done ? '' : m.rx_add, style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700)),
              ),
              RoundBtn(
                  icon: LucideIcons.x,
                  semanticLabel: s.strings.common.a11y_close,
                  ghost: true,
                  iconSize: 18,
                  onTap: () => Navigator.pop(context)),
            ]),
          ]),
        ),
        const Divider(height: 1, color: T.ink100),
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(14, 14, 14, sheetBottomInset(context, base: 36)),
            child: _done ? _Done(s: s, label: m.rx_added) : _form(s, m),
          ),
        ),
      ]),
    );
  }

  Widget _form(PatientAppState s, MedsStrings m) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _SectionLabel(icon: LucideIcons.fileText, label: s.strings.common.details, accent: s.accent.main),
      _LabeledField(s: s, label: m.rx_name, controller: _title, hint: m.rx_name_ph),
      const SizedBox(height: 14),
      _LabeledField(
          s: s, label: m.rx_doctor_name, controller: _doctor, hint: m.rx_doctor_name_ph, icon: LucideIcons.stethoscope),
      DateTimeWhen(
        when: _issued,
        onChanged: (v) => setState(() => _issued = v),
        dateLabel: m.rx_date,
        lastDate: DateTime.now(),
        expiry: _expiry,
        onExpiryChanged: (v) => setState(() => _expiry = v),
        expiryLabel: m.rx_expiry,
      ),
      const SizedBox(height: 8),
      _SectionLabel(icon: LucideIcons.uploadCloud, label: m.rx_upload, accent: s.accent.main),
      UploadDropzone(
        attach: _attach,
        url: _url.text,
        onAttach: (a) => setState(() => _attach = a),
        onUrl: (v) => setState(() => _url.text = v),
        orPasteLabel: m.rx_or_paste_url(s.gender),
        urlHint: m.rx_url_ph,
      ),
      const SizedBox(height: 18),
      _SectionLabel(icon: LucideIcons.pill, label: m.rx_manual, accent: s.accent.main),
      for (var i = 0; i < _meds.length; i++) ...[
        MedPlanCard(
          key: ObjectKey(_meds[i]),
          draft: _meds[i],
          onRemove: _meds.length > 1 ? () => setState(() => _meds.removeAt(i).dispose()) : null,
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 10),
      ],
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: PButton(
          m.rx_add_med,
          icon: LucideIcons.plus,
          variant: BtnVariant.soft,
          size: BtnSize.sm,
          accent: s.accent,
          ar: s.rtl,
          onTap: () => setState(() => _meds.add(MedPlanDraft())),
        ),
      ),
      const SizedBox(height: 20),
      Opacity(
        opacity: _ready && !_saving ? 1 : 0.4,
        child: PButton(m.rx_add,
            large: true, block: true, accent: s.accent, ar: s.rtl, onTap: _ready && !_saving ? _save : null),
      ),
    ]);
  }
}

class _Done extends StatelessWidget {
  const _Done({required this.s, required this.label});
  final PatientAppState s;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(children: [
        Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: T.hueMint50, shape: BoxShape.circle),
          child: const Icon(LucideIcons.check, size: 36, color: T.hueMint600),
        ),
        const SizedBox(height: 14),
        Text(label, style: Typo.heading(ar: s.rtl).copyWith(fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.label, required this.accent});
  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(icon, size: 15, color: accent),
        const SizedBox(width: 7),
        Text(label, style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg2)),
      ]),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.s,
    required this.label,
    required this.controller,
    required this.hint,
    this.icon,
  });
  final PatientAppState s;
  final String label;
  final TextEditingController controller;
  final String hint;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: T.fg4),
          const SizedBox(width: 6),
        ],
        Text(label, style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg2)),
      ]),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        onChanged: (_) => (context as Element).markNeedsBuild(),
        style: Typo.body(ar: s.rtl).copyWith(color: T.fg1, fontSize: FS.lg),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: Typo.body(ar: s.rtl).copyWith(color: T.fg4, fontSize: FS.lg),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(T.rMd), borderSide: const BorderSide(color: T.border, width: 1.5)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(T.rMd), borderSide: const BorderSide(color: T.border, width: 1.5)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(T.rMd), borderSide: BorderSide(color: s.accent.main, width: 1.5)),
        ),
      ),
    ]);
  }
}
