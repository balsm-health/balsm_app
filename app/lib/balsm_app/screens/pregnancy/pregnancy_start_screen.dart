import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pregnancy/pregnancy.dart';

import '../../app_state.dart';
import '../../kit.dart';
import '../../shell.dart';
import '../family/family_kit.dart';
import 'pregnancy_kit.dart';
import 'pregnancy_screen.dart';

enum _Mode { due, lastPeriod }

/// The first and last day the start screen's date pickers offer, counted in
/// calendar days to match the domain's rules (`Pregnancy.start`).
///
/// Never `now.add(Duration(days: n))`: that adds n × 24 hours, so when a
/// daylight-saving change falls in between, late in the evening it lands on
/// the next calendar day and the picker offers a day the domain then refuses.
@visibleForTesting
({DateTime first, DateTime last}) startPickerRange(DateTime now, {required bool dueDate}) {
  DateTime day(int offset) => DateTime(now.year, now.month, now.day + offset);
  return dueDate
      ? (first: day(-Pregnancy.maxDaysPast), last: day(Pregnancy.maxDaysAhead))
      : (first: day(-(PregnancyDates.termDays + Pregnancy.maxDaysPast)), last: day(0));
}

/// Start pregnancy tracking (mother-child.jsx `MCPregStartScreen`): a due
/// date, or the first day of the last period (due date estimated from it);
/// how many babies (1–8); the obstetrician's name and phone; and, optionally,
/// the next antenatal visit. With [mother] it starts tracking on that family
/// member's profile.
class PregnancyStartScreen extends ConsumerStatefulWidget {
  const PregnancyStartScreen({super.key, this.mother});

  /// Whose pregnancy (null = the account holder's own).
  final HealthProfileId? mother;
  @override
  ConsumerState<PregnancyStartScreen> createState() => _PregnancyStartScreenState();
}

class _PregnancyStartScreenState extends ConsumerState<PregnancyStartScreen> {
  _Mode _mode = _Mode.due;
  DateTime? _date;
  DateTime? _visit;
  int _count = 1;
  final _ob = TextEditingController();
  final _phone = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _ob.dispose();
    _phone.dispose();
    super.dispose();
  }

  DateTime? get _due {
    final d = _date;
    if (d == null) return null;
    return _mode == _Mode.due ? d : PregnancyDates.dueFromLastPeriod(d);
  }

  Future<void> _pick() async {
    final s = AppScope.of(context);
    final p = s.strings.pregnancy;
    final now = DateTime.now();
    final due = _mode == _Mode.due;
    final range = startPickerRange(now, dueDate: due);
    final picked = await pickDay(
      context,
      title: due ? p.due_date : p.lmp,
      initial: _date ?? now,
      first: range.first,
      last: range.last,
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  /// The optional next antenatal visit: today up to the latest possible due date.
  Future<void> _pickVisit() async {
    final p = AppScope.of(context).strings.pregnancy;
    final now = DateTime.now();
    final picked = await pickDay(
      context,
      title: p.visit_date,
      initial: _visit ?? now,
      first: DateTime(now.year, now.month, now.day),
      last: DateTime(now.year, now.month, now.day + Pregnancy.maxDaysAhead),
    );
    if (picked != null && mounted) setState(() => _visit = picked);
  }

  Future<void> _save() async {
    final due = _due;
    final mother = widget.mother ?? await ref.read(selfProfileIdProvider.future);
    if (due == null || mother == null || _saving) return;
    setState(() => _saving = true);
    final r = await ref.read(startPregnancyUseCaseProvider)(
      motherId: mother,
      dueDate: due,
      babyCount: _count,
      now: DateTime.now(),
      obName: _ob.text,
      obPhone: _phone.text,
      nextVisitOn: _visit,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (r.isFailure) {
      final s = AppScope.of(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.strings.family.save_failed(s.gender))));
      return;
    }
    final dir = AppScope.of(context).dir;
    Navigator.of(context, rootNavigator: true).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) =>
            Directionality(textDirection: dir, child: AdaptiveFrame(child: PregnancyScreen(mother: widget.mother))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.strings.pregnancy;
    final due = _due;
    final owner = pregnancyOwner(ref, widget.mother);
    return FamilyScaffold(
      title: owner == null ? p.title : p.title_of(owner.shortName),
      footer: PButton(
        owner == null ? p.start_cta : p.start_cta_of(s.gender),
        large: true,
        block: true,
        accent: s.accent,
        ar: s.rtl,
        onTap: due == null || _saving ? null : _save,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Text(
            owner == null ? p.start_note : p.start_note_of(owner.shortName, s.gender),
            style: Typo.bodySm(ar: s.rtl),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: BalsmSegmented<_Mode>(
            options: _Mode.values,
            labelOf: (m) => m == _Mode.due ? p.mode_due : p.mode_lmp,
            selected: _mode,
            onChanged: (m) => setState(() {
              _mode = m;
              _date = null;
            }),
          ),
        ),
        LabelledField(
          label: _mode == _Mode.due ? p.due_date : p.lmp,
          help: _mode == _Mode.lastPeriod && due != null ? '${p.est_due} ${formatDay(due)}' : null,
          child: DayField(value: _date, placeholder: p.pick_date, onTap: _pick),
        ),
        LabelledField(
          label: p.how_many,
          help: p.add_later,
          child: _BabyCountStepper(count: _count, onChanged: (n) => setState(() => _count = n)),
        ),
        LabelledField(
          label: p.ob,
          child: TextField(
            controller: _ob,
            maxLength: Pregnancy.maxTextLength,
            decoration: fieldDecoration(s, p.ob_name_ph).copyWith(counterText: ''),
          ),
        ),
        LabelledField(
          label: p.phone,
          child: TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            maxLength: Pregnancy.maxTextLength,
            decoration: fieldDecoration(s, '+20').copyWith(counterText: ''),
          ),
        ),
        LabelledField(
          label: '${p.next_visit_t} · ${s.strings.family.optional}',
          child: DayField(value: _visit, placeholder: p.pick_date, onTap: _pickVisit),
        ),
      ],
    );
  }
}

/// How many babies, 1 to [Pregnancy.maxBabies] (design `MCPregStartScreen`):
/// a − / + stepper with the count in the middle and, from two babies, what
/// that is called ("Twin pregnancy"…). Each button dims and stops at its end.
class _BabyCountStepper extends StatelessWidget {
  const _BabyCountStepper({required this.count, required this.onChanged});
  final int count;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.strings.pregnancy;
    final type = pregnancyTypeLabel(s, count);
    Widget step(IconData icon, String label, int to, {required bool enabled}) => Opacity(
          opacity: enabled ? 1 : 0.4,
          child: RoundBtn(
            icon: icon,
            semanticLabel: label,
            iconSize: 18,
            onTap: enabled ? () => onChanged(to) : null,
          ),
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Row(
        children: [
          step(LucideIcons.minus, p.fewer_babies, count - 1, enabled: count > 1),
          Expanded(
            // Announced as it changes, so a screen-reader user hears the count.
            child: Semantics(
              liveRegion: true,
              child: Column(
                children: [
                  Text('$count', style: Typo.num(size: FontSizes.subhead, weight: FontWeight.w700)),
                  if (type != null)
                    Text(
                      type,
                      textAlign: TextAlign.center,
                      style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ),
          ),
          step(LucideIcons.plus, p.more_babies, count + 1, enabled: count < Pregnancy.maxBabies),
        ],
      ),
    );
  }
}
