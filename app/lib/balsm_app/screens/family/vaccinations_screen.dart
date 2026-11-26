import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vaccinations/vaccinations.dart';

import '../../app_state.dart';
import '../../kit.dart';
import 'family_kit.dart';
import 'health_log_form.dart';
import 'profile_bar.dart';
import 'vaccination_draft.dart';

/// Opens person [id]'s vaccinations (mother-child.jsx `MCVaccScreen`).
Future<void> openVaccinations(BuildContext context, HealthProfileId id) =>
    pushFamilyScreen<void>(context, (_) => VaccinationsScreen(id: id));

/// Opens the add-vaccination form for [id], optionally prefilled with the
/// vaccine and dose a past-due row stands for.
Future<void> openAddVaccination(BuildContext context, HealthProfileId id, {String? vaccine, int? dose}) =>
    pushFamilyScreen<void>(context, (_) => AddVaccinationScreen(id: id, vaccine: vaccine, dose: dose));

/// Opens the vaccination form on dose [record] of [id], to change or delete it.
Future<void> openEditVaccination(BuildContext context, HealthProfileId id, VaccinationRecord record) =>
    pushFamilyScreen<void>(context, (_) => AddVaccinationScreen(id: id, editing: record));

/// A person's vaccination log: the next dose due, doses past due (each with
/// a shortcut to record it) and every dose given, newest first.
class VaccinationsScreen extends ConsumerWidget {
  const VaccinationsScreen({required this.id, super.key});
  final HealthProfileId id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final v = s.strings.vacc;
    final records = ref.watch(vaccinationsProvider(id)).value;
    final today = DateTime.now();
    final status = VaccinationStatus.of(records ?? const [], today: today);
    final next = status.next;
    return FamilyScaffold(
      title: v.title,
      bar: const ProfileBar(),
      footer: PButton(
        v.add,
        icon: LucideIcons.syringe,
        large: true,
        block: true,
        accent: s.accent,
        ar: s.rtl,
        onTap: () => openAddVaccination(context, id),
      ),
      children: [
        if (records == null)
          const SizedBox.shrink()
        else if (records.isEmpty)
          const _Empty()
        else ...[
          if (next != null) _NextDose(record: next, today: today),
          if (status.pastDue.isNotEmpty) FamilySecHead(v.past_due),
          for (final r in status.pastDue) _PastDueRow(record: r, today: today, onRecord: () => _record(context, r)),
          FamilySecHead(v.given),
          PCard(
            padding: EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.lg),
              child: Column(
                children: [
                  ...records.indexed.map(
                    (e) => _GivenRow(
                      record: e.$2,
                      divider: e.$1 > 0,
                      onTap: () => openEditVaccination(context, id, e.$2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _record(BuildContext context, VaccinationRecord r) =>
      openAddVaccination(context, id, vaccine: r.vaccine, dose: r.doseNumber + 1);
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final v = s.strings.vacc;
    return PCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Column(
        children: [
          const IconSquare(
            LucideIcons.syringe,
            bg: AppColors.hueEmerald50,
            fg: AppColors.hueEmeraldInk,
            size: 52,
            iconSize: 24,
            radius: 16,
          ),
          const SizedBox(height: 10),
          Text(
            v.empty_t,
            textAlign: TextAlign.center,
            style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 270),
            child: Text(
              v.empty_b(s.gender),
              textAlign: TextAlign.center,
              style: Typo.bodySm(ar: s.rtl).copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// The accent card with the soonest dose still to come.
class _NextDose extends StatelessWidget {
  const _NextDose({required this.record, required this.today});
  final VaccinationRecord record;
  final DateTime today;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final v = s.strings.vacc;
    final due = record.nextDueOn!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: s.accent.bg, borderRadius: BorderRadius.circular(AppRadii.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(v.next_dose, style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: s.accent.d)),
          const SizedBox(height: 2),
          Text(
            '${record.vaccine} · ${v.dose(record.doseNumber + 1)}',
            style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(LucideIcons.calendar, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Flexible(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: formatDay(due),
                        style: Typo.num(
                          size: FontSizes.bodySm,
                          weight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      TextSpan(text: ' · ${v.in_days(VaccinationStatus.daysBetween(today, due))}'),
                    ],
                  ),
                  style: Typo.bodySm(ar: s.rtl),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PastDueRow extends StatelessWidget {
  const _PastDueRow({required this.record, required this.today, required this.onRecord});
  final VaccinationRecord record;
  final DateTime today;
  final VoidCallback onRecord;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final v = s.strings.vacc;
    final due = record.nextDueOn!;
    final ago = VaccinationStatus.daysBetween(due, today);
    return PCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          const IconSquare(LucideIcons.clock, bg: AppColors.ink50, fg: AppColors.textSecondary, iconSize: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${record.vaccine} · ${v.dose(record.doseNumber + 1)}',
                  style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                Text(
                  '${v.was_due(formatDay(due))} · ${ago == 0 ? v.due_today : v.days_ago(ago)}',
                  style: Typo.meta(ar: s.rtl),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PButton(v.record, variant: BtnVariant.secondary, size: BtnSize.sm, ar: s.rtl, onTap: onRecord),
        ],
      ),
    );
  }
}

/// A dose given; tapping it opens the form to edit or delete it.
class _GivenRow extends StatelessWidget {
  const _GivenRow({required this.record, required this.divider, required this.onTap});
  final VaccinationRecord record;
  final bool divider;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final v = s.strings.vacc;
    return Semantics(
      button: true,
      child: Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
          decoration: divider ? const BoxDecoration(border: Border(top: BorderSide(color: AppColors.ink100))) : null,
          child: Row(
            children: [
              const IconSquare(
                LucideIcons.check,
                bg: AppColors.hueEmerald50,
                fg: AppColors.hueEmeraldInk,
                size: 36,
                iconSize: 17,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.vaccine,
                      style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: '${v.dose(record.doseNumber)} · '),
                          TextSpan(
                            text: formatDay(record.administeredOn),
                            style:
                                Typo.num(size: FontSizes.meta, weight: FontWeight.w500, color: AppColors.textTertiary),
                          ),
                          if (record.clinic != null) TextSpan(text: ' · ${record.clinic}'),
                        ],
                      ),
                      style: Typo.meta(ar: s.rtl),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(LucideIcons.pencil, size: 15, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Add a vaccination (`MCVaccAddScreen`): the vaccine's name as written on
/// the card, the dose number, the day given (not after today), where, and
/// an optional next due day after the day given. With [editing] it is the
/// edit form (`prefill.edit`): prefilled with that dose, saving over it, and
/// offering to delete it after a confirm sheet (`MCConfirmSheet`).
class AddVaccinationScreen extends ConsumerStatefulWidget {
  const AddVaccinationScreen({required this.id, super.key, this.vaccine, this.dose, this.editing});
  final HealthProfileId id;
  final String? vaccine;
  final int? dose;

  /// The dose being edited; null for a new one.
  final VaccinationRecord? editing;
  @override
  ConsumerState<AddVaccinationScreen> createState() => _AddVaccinationScreenState();
}

class _AddVaccinationScreenState extends ConsumerState<AddVaccinationScreen> {
  late final _name = TextEditingController(text: widget.editing?.vaccine ?? widget.vaccine ?? '');
  late final _clinic = TextEditingController(text: widget.editing?.clinic ?? '');
  late final VaccinationDraftKey _key = (form: Object(), editing: widget.editing, dose: widget.dose);
  bool _saving = false;

  PatientAppState get s => AppScope.of(context);

  @override
  void dispose() {
    _name.dispose();
    _clinic.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final editing = widget.editing;
    final draft = ref.read(vaccinationDraftProvider(_key));
    final result = editing == null
        ? await ref.read(recordVaccinationUseCaseProvider)(
            vaccine: _name.text,
            doseNumber: draft.dose,
            administeredOn: draft.given,
            clinic: _clinic.text,
            nextDueOn: draft.next,
            now: DateTime.now(),
            profileId: widget.id,
          )
        : await ref.read(updateVaccinationUseCaseProvider)(
            id: editing.id,
            vaccine: _name.text,
            doseNumber: draft.dose,
            administeredOn: draft.given,
            clinic: _clinic.text,
            nextDueOn: draft.next,
            now: DateTime.now(),
            profileId: widget.id,
          );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.isFailure) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.strings.family.save_failed(s.gender))));
      return;
    }
    Navigator.pop(context);
  }

  Future<void> _delete(VaccinationRecord record) async {
    final v = s.strings.vacc;
    final yes = await showFamilyConfirmSheet(context, title: v.delete_t, body: v.delete_b);
    if (!yes || !mounted) return;
    setState(() => _saving = true);
    final result = await ref.read(deleteVaccinationUseCaseProvider)(record.id, profileId: widget.id);
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.isFailure) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.strings.family.save_failed(s.gender))));
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final v = s.strings.vacc;
    final editing = widget.editing;
    final ok = ref.watch(
      vaccinationDraftProvider(_key)
          .select((d) => d.violations(vaccine: _name.text, clinic: _clinic.text, now: DateTime.now()).isEmpty),
    );
    return FamilyScaffold(
      title: editing == null ? v.add : v.edit_t,
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PButton(
            editing == null ? v.save : v.save_changes,
            large: true,
            block: true,
            accent: s.accent,
            ar: s.rtl,
            onTap: ok && !_saving ? _save : null,
          ),
          if (editing != null) ...[
            const SizedBox(height: 8),
            PButton(
              v.delete,
              icon: LucideIcons.trash2,
              variant: BtnVariant.ghost,
              block: true,
              color: AppColors.danger,
              ar: s.rtl,
              onTap: _saving ? null : () => _delete(editing),
            ),
          ],
        ],
      ),
      children: [
        LogField(
          label: v.f_name,
          child: TextField(
            controller: _name,
            maxLength: VaccinationRecord.maxVaccineLength,
            onChanged: (_) => setState(() {}),
            style: Typo.body(ar: s.rtl).copyWith(color: AppColors.textPrimary),
            decoration: logInputDecoration(s, v.f_name_ph),
          ),
        ),
        LogField(label: v.f_dose, child: _DoseField(draftKey: _key)),
        LogField(label: v.f_date, child: _GivenField(draftKey: _key)),
        LogField(
          label: v.f_clinic,
          child: TextField(
            controller: _clinic,
            maxLength: VaccinationRecord.maxClinicLength,
            onChanged: (_) => setState(() {}),
            style: Typo.body(ar: s.rtl).copyWith(color: AppColors.textPrimary),
            decoration: logInputDecoration(s, v.f_clinic_ph),
          ),
        ),
        LogField(
          label: v.f_next,
          trailing: v.optional,
          hint: v.f_next_hint(s.gender),
          child: _NextDueField(draftKey: _key),
        ),
      ],
    );
  }
}

/// The dose-number chips: 1–5, or up to the dose being recorded when higher.
class _DoseField extends ConsumerWidget {
  const _DoseField({required this.draftKey});
  final VaccinationDraftKey draftKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dose = ref.watch(vaccinationDraftProvider(draftKey).select((d) => d.dose));
    final doses = [for (var n = 1; n <= (dose > 5 ? dose : 5); n++) n];
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 8.0;
        final w = (c.maxWidth - gap * 4) / 5;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: doses
              .map(
                (n) => SizedBox(
                  width: w,
                  child: _DoseChip(
                    n: n,
                    active: dose == n,
                    onTap: () => ref.read(vaccinationDraftProvider(draftKey).notifier).setDose(n),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

/// The day the dose was given: not after today.
class _GivenField extends ConsumerWidget {
  const _GivenField({required this.draftKey});
  final VaccinationDraftKey draftKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = AppScope.of(context).strings.vacc;
    final given = ref.watch(vaccinationDraftProvider(draftKey).select((d) => d.given));
    final now = DateTime.now();
    return LogDateField(
      value: given,
      title: v.f_date,
      first: DateTime(now.year - 120),
      last: now,
      onPicked: (d) => ref.read(vaccinationDraftProvider(draftKey).notifier).setGiven(d),
    );
  }
}

/// The optional next due day: after the day given.
class _NextDueField extends ConsumerWidget {
  const _NextDueField({required this.draftKey});
  final VaccinationDraftKey draftKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = AppScope.of(context).strings.vacc;
    final (given, next) = ref.watch(vaccinationDraftProvider(draftKey).select((d) => (d.given, d.next)));
    final now = DateTime.now();
    VaccinationDraftNotifier notifier() => ref.read(vaccinationDraftProvider(draftKey).notifier);
    return LogDateField(
      value: next,
      title: v.f_next,
      first: given.add(const Duration(days: 1)),
      last: DateTime(now.year + 20),
      onPicked: (d) => notifier().setNext(d),
      onClear: () => notifier().setNext(null),
    );
  }
}

/// One of the dose-number chips.
class _DoseChip extends StatelessWidget {
  const _DoseChip({required this.n, required this.active, required this.onTap});
  final int n;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Semantics(
      button: true,
      selected: active,
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.fast,
          padding: const EdgeInsets.symmetric(vertical: 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? s.accent.main : AppColors.white,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(color: active ? s.accent.main : AppColors.border, width: 1.5),
          ),
          child: Text(
            '$n',
            style: Typo.num(
              weight: FontWeight.w700,
              color: active ? ColorContrast.onFill(s.accent.main) : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
