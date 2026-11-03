import 'package:core/core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:vaccinations/vaccinations.dart';

import '../../app_state.dart';
import '../../kit.dart';
import '../../tokens.dart';
import 'family_kit.dart';
import 'health_log_form.dart';
import 'profile_bar.dart';

/// Opens person [id]'s vaccinations (mother-child.jsx `MCVaccScreen`).
Future<void> openVaccinations(BuildContext context, HealthProfileId id) =>
    pushFamilyScreen<void>(context, (_) => VaccinationsScreen(id: id));

/// Opens the add-vaccination form for [id], optionally prefilled with the
/// vaccine and dose a past-due row stands for.
Future<void> openAddVaccination(BuildContext context, HealthProfileId id, {String? vaccine, int? dose}) =>
    pushFamilyScreen<void>(context, (_) => AddVaccinationScreen(id: id, vaccine: vaccine, dose: dose));

/// A person's vaccination log: the next dose due, doses past due (each with
/// a shortcut to record it) and every dose given, newest first.
class VaccinationsScreen extends ConsumerWidget {
  const VaccinationsScreen({super.key, required this.id});
  final HealthProfileId id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final v = s.strings.vacc;
    final records = ref.watch(vaccinationsProvider(id)).valueOrNull;
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
              borderRadius: BorderRadius.circular(T.rLg),
              child: Column(children: [
                for (final (i, r) in records.indexed) _GivenRow(record: r, divider: i > 0),
              ]),
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
      child: Column(children: [
        const IconSquare(LucideIcons.syringe,
            bg: T.hueEmerald50, fg: T.hueEmeraldInk, size: 52, iconSize: 24, radius: 16),
        const SizedBox(height: 10),
        Text(v.empty_t,
            textAlign: TextAlign.center,
            style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg1)),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 270),
          child: Text(v.empty_b(s.gender),
              textAlign: TextAlign.center, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg2)),
        ),
      ]),
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
      decoration: BoxDecoration(color: s.accent.bg, borderRadius: BorderRadius.circular(T.rLg)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(v.next_dose, style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: s.accent.d)),
        const SizedBox(height: 2),
        Text('${record.vaccine} · ${v.dose(record.doseNumber + 1)}',
            style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
        const SizedBox(height: 2),
        Row(children: [
          const Icon(LucideIcons.calendar, size: 14, color: T.fg2),
          const SizedBox(width: 6),
          Flexible(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: formatDay(due), style: Typo.num(size: FS.sm, weight: FontWeight.w500, color: T.fg2)),
                TextSpan(text: ' · ${v.in_days(VaccinationStatus.daysBetween(today, due))}'),
              ]),
              style: Typo.bodySm(ar: s.rtl),
            ),
          ),
        ]),
      ]),
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
      child: Row(children: [
        const IconSquare(LucideIcons.clock, bg: T.ink50, fg: T.fg2, size: 38, iconSize: 18, radius: 10),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${record.vaccine} · ${v.dose(record.doseNumber + 1)}',
                style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
            Text('${v.was_due(formatDay(due))} · ${ago == 0 ? v.due_today : v.days_ago(ago)}',
                style: Typo.meta(ar: s.rtl)),
          ]),
        ),
        const SizedBox(width: 8),
        PButton(v.record, variant: BtnVariant.secondary, size: BtnSize.sm, ar: s.rtl, onTap: onRecord),
      ]),
    );
  }
}

class _GivenRow extends StatelessWidget {
  const _GivenRow({required this.record, required this.divider});
  final VaccinationRecord record;
  final bool divider;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final v = s.strings.vacc;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
      decoration: divider ? const BoxDecoration(border: Border(top: BorderSide(color: T.ink100))) : null,
      child: Row(children: [
        const IconSquare(LucideIcons.check, bg: T.hueEmerald50, fg: T.hueEmeraldInk, size: 36, iconSize: 17),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(record.vaccine, style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
            Text.rich(
              TextSpan(children: [
                TextSpan(text: '${v.dose(record.doseNumber)} · '),
                TextSpan(
                  text: formatDay(record.administeredOn),
                  style: Typo.num(size: FS.xs, weight: FontWeight.w500, color: T.fg3),
                ),
                if (record.clinic != null) TextSpan(text: ' · ${record.clinic}'),
              ]),
              style: Typo.meta(ar: s.rtl),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// Add a vaccination (`MCVaccAddScreen`): the vaccine's name as written on
/// the card, the dose number, the day given (not after today), where, and
/// an optional next due day after the day given.
class AddVaccinationScreen extends ConsumerStatefulWidget {
  const AddVaccinationScreen({super.key, required this.id, this.vaccine, this.dose});
  final HealthProfileId id;
  final String? vaccine;
  final int? dose;
  @override
  ConsumerState<AddVaccinationScreen> createState() => _AddVaccinationScreenState();
}

class _AddVaccinationScreenState extends ConsumerState<AddVaccinationScreen> {
  late final _name = TextEditingController(text: widget.vaccine ?? '');
  final _clinic = TextEditingController();
  late int _dose = widget.dose ?? 1;
  DateTime? _given = DateTime.now();
  DateTime? _next;
  bool _saving = false;

  PatientAppState get s => AppScope.of(context);

  @override
  void dispose() {
    _name.dispose();
    _clinic.dispose();
    super.dispose();
  }

  bool get _ok => VaccinationRecord.violationsOf(
        vaccine: _name.text,
        doseNumber: _dose,
        administeredOn: _given,
        clinic: _clinic.text,
        nextDueOn: _next,
        now: DateTime.now(),
      ).isEmpty;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final result = await ref.read(recordVaccinationUseCaseProvider)(
      vaccine: _name.text,
      doseNumber: _dose,
      administeredOn: _given,
      clinic: _clinic.text,
      nextDueOn: _next,
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

  @override
  Widget build(BuildContext context) {
    final v = s.strings.vacc;
    final now = DateTime.now();
    final given = _given;
    final doses = [for (var n = 1; n <= (_dose > 5 ? _dose : 5); n++) n];
    return FamilyScaffold(
      title: v.add,
      footer: PButton(
        v.save,
        large: true,
        block: true,
        accent: s.accent,
        ar: s.rtl,
        onTap: _ok && !_saving ? _save : null,
      ),
      children: [
        LogField(
          label: v.f_name,
          child: TextField(
            controller: _name,
            maxLength: VaccinationRecord.maxVaccineLength,
            onChanged: (_) => setState(() {}),
            style: Typo.body(ar: s.rtl).copyWith(color: T.fg1),
            decoration: logInputDecoration(s, v.f_name_ph),
          ),
        ),
        LogField(
          label: v.f_dose,
          child: LayoutBuilder(builder: (context, c) {
            const gap = 8.0;
            final w = (c.maxWidth - gap * 4) / 5;
            return Wrap(spacing: gap, runSpacing: gap, children: [
              for (final n in doses)
                SizedBox(
                  width: w,
                  child: _DoseChip(n: n, active: _dose == n, onTap: () => setState(() => _dose = n)),
                ),
            ]);
          }),
        ),
        LogField(
          label: v.f_date,
          child: LogDateField(
            value: given,
            title: v.f_date,
            first: DateTime(now.year - 120),
            last: now,
            onPicked: (d) => setState(() {
              _given = d;
              final next = _next;
              if (next != null && !next.isAfter(d)) _next = null;
            }),
          ),
        ),
        LogField(
          label: v.f_clinic,
          child: TextField(
            controller: _clinic,
            maxLength: VaccinationRecord.maxClinicLength,
            onChanged: (_) => setState(() {}),
            style: Typo.body(ar: s.rtl).copyWith(color: T.fg1),
            decoration: logInputDecoration(s, v.f_clinic_ph),
          ),
        ),
        LogField(
          label: v.f_next,
          trailing: v.optional,
          hint: v.f_next_hint(s.gender),
          child: LogDateField(
            value: _next,
            title: v.f_next,
            first: (given ?? now).add(const Duration(days: 1)),
            last: DateTime(now.year + 20),
            onPicked: (d) => setState(() => _next = d),
            onClear: () => setState(() => _next = null),
          ),
        ),
      ],
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
            color: active ? s.accent.main : Colors.white,
            borderRadius: BorderRadius.circular(T.rPill),
            border: Border.all(color: active ? s.accent.main : T.border, width: 1.5),
          ),
          child: Text(
            '$n',
            style: Typo.num(size: FS.md, weight: FontWeight.w700, color: active ? T.onFill(s.accent.main) : T.fg2),
          ),
        ),
      ),
    );
  }
}
