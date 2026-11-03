import 'package:core/core.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:medications/medications.dart';

import '../app_state.dart';
import '../i18n/strings.i69n.dart';
import '../kit.dart';
import '../tokens.dart';
import 'select_field.dart';

/// One medication as typed into a form (prescriptions.jsx `MedRow` +
/// `AddMedSheet`'s dose-time slots).
///
/// Shared by Add medication and Add prescription, so a med typed into either
/// lands in the Meds tab's daily list the same way. On-device PHI only.
class MedPlanDraft {
  MedPlanDraft();

  final name = TextEditingController();
  final dose = TextEditingController();
  final notes = TextEditingController();
  final freqN = TextEditingController(text: '2');
  final freqOther = TextEditingController();
  final durN = TextEditingController();
  final durOther = TextEditingController();

  /// `once` · `per_day` · `every_x` · `other` — the design's frequency ids.
  String freqType = 'once';

  /// `hours` · `days`, for `every_x`.
  String freqUnit = 'hours';

  /// `period` · `until_empty` · `ongoing` · `other`.
  String durType = 'ongoing';

  /// `days` · `weeks` · `months`, for `period`.
  String durUnit = 'days';

  /// Dose times: one for a single dose (or the first dose of "every X
  /// hours"), one per dose for 2+ per day. Kept in step with the count by
  /// [syncTimes].
  List<String> times = suggestedTimes(2);

  static const morningTime = '08:00';

  bool get isNamed => name.text.trim().isNotEmpty;

  int get _n => (int.tryParse(freqN.text) ?? 1).clamp(1, 99);

  int get perDay => _n.clamp(1, 12);

  /// Which timing control the form shows for the current frequency.
  MedTiming get timing => switch (freqType) {
        'per_day' when perDay > 1 => MedTiming.times,
        'every_x' when freqUnit == 'hours' => MedTiming.firstDose,
        _ => MedTiming.single,
      };

  /// Re-suggests [times] when the dose count changes. A count the patient has
  /// already tuned by hand is left alone.
  void syncTimes() {
    switch (timing) {
      case MedTiming.times:
        if (times.length != perDay) times = suggestedTimes(perDay);
      case MedTiming.firstDose || MedTiming.single:
        if (times.length != 1) times = [times.firstOrNull ?? morningTime];
    }
  }

  String get _single => times.firstOrNull ?? morningTime;

  /// The scheduled medication. It starts at midnight today, so a dose due
  /// earlier today is listed as Due rather than silently skipped.
  Medication toMedication(UserId userId, {DateTime? now}) {
    final today = DateUtils.dateOnly(now ?? DateTime.now());
    final text = freqOther.text.trim();
    final (type, times, interval) = switch (freqType) {
      'once' => (ScheduleType.once, [_single], null),
      'per_day' when perDay > 1 => (ScheduleType.daily, [...this.times], null),
      'every_x' when freqUnit == 'hours' => (ScheduleType.everyHours, [this.times.first], _n),
      'every_x' when _n > 1 => (ScheduleType.everyDays, [_single], _n),
      _ => (ScheduleType.daily, [_single], null),
    };
    final count = int.tryParse(durN.text) ?? 0;
    final period = durType == 'period' && count > 0;
    final durText = durOther.text.trim();
    return Medication(
      id: MedicationId.uuid(),
      userId: userId,
      name: name.text.trim(),
      doseAmount: dose.text.trim().isEmpty ? null : dose.text.trim(),
      scheduleType: type,
      scheduleConfig: ScheduleConfig(
        times: times,
        interval: interval,
        frequencyNote: freqType == 'other' && text.isNotEmpty ? text : null,
        durationKind: switch (durType) {
          'period' when period => DurationKind.period,
          'until_empty' => DurationKind.untilEmpty,
          'other' => DurationKind.other,
          _ => DurationKind.ongoing,
        },
        durationNote: durType == 'other' && durText.isNotEmpty ? durText : null,
      ),
      startDate: today,
      endDate: period ? periodEnd(today, count, PeriodUnit.values.byName(durUnit)) : null,
      notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
    );
  }

  /// "500 mg · 2×/day · 7 days" — the one-line summary a prescription keeps.
  String summary(MedsStrings m) {
    final freq = switch (freqType) {
      'once' => m.freq_once,
      'per_day' => m.freq_n_per_day('$perDay'),
      'every_x' => '${m.freq_every} $_n ${freqUnit == 'days' ? m.unit_days : m.unit_hours}',
      _ => freqOther.text.trim().isEmpty ? m.freq_other : freqOther.text.trim(),
    };
    final dur = switch (durType) {
      'until_empty' => m.dur_until_empty,
      'other' => durOther.text.trim().isEmpty ? null : durOther.text.trim(),
      'period' when durN.text.isNotEmpty =>
        '${durN.text} ${switch (durUnit) { 'weeks' => m.unit_weeks, 'months' => m.unit_months, _ => m.unit_days }}',
      _ => null,
    };
    return [dose.text.trim(), freq, dur].where((p) => p != null && p.isNotEmpty).join(' · ');
  }

  void dispose() {
    for (final c in [name, dose, notes, freqN, freqOther, durN, durOther]) {
      c.dispose();
    }
  }
}

enum MedTiming { single, times, firstDose }

/// The medication fields card: name, dose, notes, frequency, duration and when
/// it's taken. [onChanged] rebuilds the owner (its Save button depends on the
/// name).
class MedPlanCard extends StatelessWidget {
  const MedPlanCard({super.key, required this.draft, required this.onChanged, this.onRemove});
  final MedPlanDraft draft;
  final VoidCallback onChanged;

  /// Shows the remove button when set (more than one med in a prescription).
  final VoidCallback? onRemove;

  void _set(VoidCallback change) {
    change();
    draft.syncTimes();
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final m = s.strings.meds;
    final d = draft;
    return PCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(14),
      child: Stack(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _Input(controller: d.name, hint: m.rx_med_name_ph, onChanged: onChanged),
          const SizedBox(height: 12),
          _Input(controller: d.dose, hint: m.rx_med_dose_ph, onChanged: onChanged),
          const SizedBox(height: 12),
          _Input(controller: d.notes, hint: m.rx_med_desc_ph, onChanged: onChanged, lines: 2),
          const SizedBox(height: 12),
          _FieldLabel(m.rx_frequency),
          Row(children: [
            Expanded(
              child: SelectField<String>(
                value: d.freqType,
                items: [
                  ('once', m.freq_once),
                  ('per_day', m.freq_per_day),
                  ('every_x', m.freq_every_x),
                  ('other', m.freq_other),
                ],
                onChanged: (v) => _set(() => d.freqType = v),
              ),
            ),
            if (d.freqType == 'per_day' || d.freqType == 'every_x') ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 64,
                child: _Input(controller: d.freqN, number: true, onChanged: () => _set(() {})),
              ),
            ],
            if (d.freqType == 'every_x') ...[
              const SizedBox(width: 8),
              Expanded(
                child: SelectField<String>(
                  value: d.freqUnit,
                  items: [('hours', m.unit_hours), ('days', m.unit_days)],
                  onChanged: (v) => _set(() => d.freqUnit = v),
                ),
              ),
            ],
          ]),
          if (d.freqType == 'other') ...[
            const SizedBox(height: 8),
            _Input(controller: d.freqOther, hint: m.freq_other_ph(s.gender), onChanged: onChanged),
          ],
          const SizedBox(height: 12),
          _FieldLabel(m.rx_duration),
          SelectField<String>(
            value: d.durType,
            items: [
              ('period', m.dur_period),
              ('until_empty', m.dur_until_empty),
              ('ongoing', m.dur_ongoing),
              ('other', m.dur_other),
            ],
            onChanged: (v) => _set(() => d.durType = v),
          ),
          if (d.durType == 'period') ...[
            const SizedBox(height: 8),
            Row(children: [
              SizedBox(
                width: 56,
                child: Semantics(
                  label: m.dur_count,
                  child: _Input(controller: d.durN, hint: '1', number: true, onChanged: onChanged),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SelectField<String>(
                  value: d.durUnit,
                  items: [('days', m.unit_days), ('weeks', m.unit_weeks), ('months', m.unit_months)],
                  onChanged: (v) => _set(() => d.durUnit = v),
                ),
              ),
            ]),
          ],
          if (d.durType == 'other') ...[
            const SizedBox(height: 8),
            _Input(controller: d.durOther, hint: m.dur_other_ph(s.gender), onChanged: onChanged),
          ],
          const SizedBox(height: 14),
          _Timing(draft: d, onChanged: onChanged),
        ]),
        if (onRemove != null)
          PositionedDirectional(
            top: 0,
            end: 0,
            child: Material(
              color: T.ink50,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onRemove,
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: Semantics(
                    label: s.strings.common.a11y_close,
                    child: const Icon(LucideIcons.x, size: 13, color: T.fg3),
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

/// When the doses happen (AddMedSheet's time slots): one time for a single
/// dose or the first dose of an hourly interval, one slot per dose — two to a
/// row — for several a day.
class _Timing extends StatelessWidget {
  const _Timing({required this.draft, required this.onChanged});
  final MedPlanDraft draft;
  final VoidCallback onChanged;

  Future<void> _pick(BuildContext context, int i) async {
    final picked = await showTimePicker(context: context, initialTime: _timeOf(draft.times[i]));
    if (picked == null) return;
    draft.times = [...draft.times]..[i] =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final m = s.strings.meds;
    final several = draft.timing == MedTiming.times;
    final label = switch (draft.timing) {
      MedTiming.times => m.med_dose_times,
      MedTiming.firstDose => m.med_first_dose,
      MedTiming.single => m.med_when,
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _FieldLabel(label, strong: true),
      LayoutBuilder(builder: (context, box) {
        final w = several ? (box.maxWidth - 8) / 2 : box.maxWidth;
        return Wrap(spacing: 8, runSpacing: 8, children: [
          for (var i = 0; i < draft.times.length; i++)
            SizedBox(
              width: w,
              child: _TimeSlot(
                time: _timeOf(draft.times[i]),
                dose: several ? i + 1 : null,
                onTap: () => _pick(context, i),
              ),
            ),
        ]);
      }),
    ]);
  }
}

TimeOfDay _timeOf(String hhmm) {
  final parts = hhmm.split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

/// One dose time (AddMedSheet's time slot): the part of the day's icon, the
/// time in the locale's clock, "Dose N" when there are several, and a clock.
/// Tapping it opens the time picker.
class _TimeSlot extends StatelessWidget {
  const _TimeSlot({required this.time, required this.onTap, this.dose});
  final TimeOfDay time;
  final int? dose;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final m = s.strings.meds;
    final h = time.hour;
    final icon = h >= 5 && h < 12
        ? LucideIcons.sunrise
        : h >= 12 && h < 18
            ? LucideIcons.sun
            : LucideIcons.moon;
    final text = MaterialLocalizations.of(context).formatTimeOfDay(time);
    final dose = this.dose;
    return Semantics(
      button: true,
      label: '${dose == null ? m.med_when : m.med_dose_n_time(dose)}: $text',
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        scale: 0.97,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(T.rMd),
            border: Border.all(color: T.border, width: 1.5),
          ),
          child: Row(children: [
            Icon(icon, size: 16, color: s.accent.d),
            const SizedBox(width: 7),
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  text,
                  textDirection: TextDirection.ltr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Typo.num(size: FS.sm, weight: FontWeight.w600, color: T.fg1),
                ),
              ),
            ),
            if (dose != null) ...[
              const SizedBox(width: 7),
              Text(m.med_dose_n(dose), style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg3)),
            ],
            const SizedBox(width: 7),
            const Icon(LucideIcons.clock, size: 15, color: T.fg3),
          ]),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {this.strong = false});
  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: strong ? 8 : 6),
      child: Text(
        text,
        style: strong
            ? Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg2)
            : Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg3),
      ),
    );
  }
}

OutlineInputBorder _border(Color color) =>
    OutlineInputBorder(borderRadius: BorderRadius.circular(T.rMd), borderSide: BorderSide(color: color, width: 1.5));

class _Input extends StatelessWidget {
  const _Input({required this.controller, required this.onChanged, this.hint, this.lines = 1, this.number = false});
  final TextEditingController controller;
  final VoidCallback onChanged;
  final String? hint;
  final int lines;
  final bool number;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return TextField(
      controller: controller,
      minLines: lines,
      maxLines: lines,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      textAlign: number ? TextAlign.center : TextAlign.start,
      onChanged: (_) => onChanged(),
      style: Typo.body(ar: s.rtl).copyWith(color: T.fg1, fontSize: FS.lg),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: Typo.body(ar: s.rtl).copyWith(color: T.fgPlaceholder, fontSize: FS.lg),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: _border(T.border),
        enabledBorder: _border(T.border),
        focusedBorder: _border(s.accent.main),
      ),
    );
  }
}
