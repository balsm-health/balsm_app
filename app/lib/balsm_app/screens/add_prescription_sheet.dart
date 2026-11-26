import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../kit.dart';
import '../maintenance/maintenance_guard.dart';
import '../widgets/date_time_row.dart';
import '../widgets/med_plan_form.dart';
import '../widgets/photo_attach.dart';
import 'prescription_draft.dart';

Future<void> showAddPrescription(BuildContext context) async => maintenancePaused(context)
    ? null
    : showAppSheet<void>(
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
  /// This sheet's own draft in [prescriptionDraftProvider], gone when it closes.
  final _form = Object();
  final _title = TextEditingController();
  final _doctor = TextEditingController();
  bool _saving = false;
  bool _done = false;

  @override
  void dispose() {
    _title.dispose();
    _doctor.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final m = AppScope.of(context).strings.meds;
    setState(() => _saving = true);
    final title = _title.text.trim();
    final saved = await ref.read(prescriptionDraftProvider(_form).notifier).save(
          title: title.isEmpty ? m.rx_default_title : title,
          doctor: _doctor.text.trim(),
          strings: m,
        );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _done = saved;
    });
    if (!saved) return;
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
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 16, 10),
            child: Column(
              children: [
                if (!_done)
                  const Center(
                    child: SheetGrab(),
                  ),
                if (!_done) const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _done ? '' : m.rx_add,
                        style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    RoundBtn(
                      icon: LucideIcons.x,
                      semanticLabel: s.strings.common.a11y_close,
                      ghost: true,
                      iconSize: 18,
                      onTap: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.ink100),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsetsDirectional.fromSTEB(14, 14, 14, sheetBottomInset(context, base: 36)),
              child: _done
                  ? _Done(s: s, label: m.rx_added)
                  : _PrescriptionForm(
                      form: _form,
                      title: _title,
                      doctor: _doctor,
                      saving: _saving,
                      onSave: _save,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The sheet's fields. Watches the draft, so an edit rebuilds the form and not
/// the sheet around it.
class _PrescriptionForm extends ConsumerWidget {
  const _PrescriptionForm({
    required this.form,
    required this.title,
    required this.doctor,
    required this.saving,
    required this.onSave,
  });

  /// The key of this sheet's draft in [prescriptionDraftProvider].
  final Object form;
  final TextEditingController title;
  final TextEditingController doctor;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final m = s.strings.meds;
    final draft = ref.watch(prescriptionDraftProvider(form));
    final notifier = ref.read(prescriptionDraftProvider(form).notifier);
    final canSave = draft.ready && !saving;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(icon: LucideIcons.fileText, label: s.strings.common.details, accent: s.accent.main),
        _LabeledField(s: s, label: m.rx_name, controller: title, hint: m.rx_name_ph),
        const SizedBox(height: 14),
        _LabeledField(
          s: s,
          label: m.rx_doctor_name,
          controller: doctor,
          hint: m.rx_doctor_name_ph,
          icon: LucideIcons.stethoscope,
        ),
        DateTimeWhen(
          when: draft.issued,
          onChanged: notifier.setIssued,
          dateLabel: m.rx_date,
          lastDate: DateTime.now(),
          expiry: draft.expiry,
          onExpiryChanged: notifier.setExpiry,
          expiryLabel: m.rx_expiry,
        ),
        const SizedBox(height: 8),
        _SectionLabel(icon: LucideIcons.uploadCloud, label: m.rx_upload, accent: s.accent.main),
        UploadDropzone(
          attach: draft.attach,
          url: draft.url,
          // The picker answers after an await; the sheet may be closed by then.
          onAttach: (a) {
            if (context.mounted) notifier.attach(a);
          },
          onUrl: notifier.setUrl,
          orPasteLabel: m.rx_or_paste_url(s.gender),
          urlHint: m.rx_url_ph,
        ),
        const SizedBox(height: 18),
        _SectionLabel(icon: LucideIcons.pill, label: m.rx_manual, accent: s.accent.main),
        ...draft.meds.expand(
          (med) => [
            MedPlanCard(
              key: ValueKey(med.key),
              draft: med.plan,
              onRemove: draft.meds.length > 1 ? () => notifier.removeMed(med.key) : null,
              onChanged: (plan) => notifier.updateMed(med.key, plan),
            ),
            const SizedBox(height: 10),
          ],
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: PButton(
            m.rx_add_med,
            icon: LucideIcons.plus,
            variant: BtnVariant.soft,
            size: BtnSize.sm,
            accent: s.accent,
            ar: s.rtl,
            onTap: notifier.addMed,
          ),
        ),
        const SizedBox(height: 20),
        Opacity(
          opacity: canSave ? 1 : 0.4,
          child: PButton(
            m.rx_add,
            large: true,
            block: true,
            accent: s.accent,
            ar: s.rtl,
            onTap: canSave ? onSave : null,
          ),
        ),
      ],
    );
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
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.hueMint50, shape: BoxShape.circle),
            child: const Icon(LucideIcons.check, size: 36, color: AppColors.hueMint600),
          ),
          const SizedBox(height: 14),
          Text(label, style: Typo.heading(ar: s.rtl).copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
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
      child: Row(
        children: [
          Icon(icon, size: 15, color: accent),
          const SizedBox(width: 7),
          Text(
            label,
            style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
        ],
      ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: AppColors.textHint),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          onChanged: (_) => (context as Element).markNeedsBuild(),
          style: Typo.body(ar: s.rtl).copyWith(color: AppColors.textPrimary, fontSize: FontSizes.subhead),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: Typo.body(ar: s.rtl).copyWith(color: AppColors.textHint, fontSize: FontSizes.subhead),
            filled: true,
            fillColor: AppColors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.md),
              borderSide: const BorderSide(color: AppColors.border, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.md),
              borderSide: const BorderSide(color: AppColors.border, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.md),
              borderSide: BorderSide(color: s.accent.main, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
