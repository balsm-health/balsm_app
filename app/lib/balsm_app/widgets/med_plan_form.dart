import 'package:core/core.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../kit.dart';
import 'med_plan_draft.dart';
import 'select_field.dart';

export 'med_plan_draft.dart';

/// The medication fields card: name, dose, notes, frequency, duration and when
/// it's taken.
///
/// The card owns its text controllers (view state); every edit reports a new
/// [MedPlanDraft] through [onChanged], and the owner keeps it in a Notifier
/// (its Save button depends on the name). The controllers start from [draft]
/// once, so the owner keys a card per medication.
class MedPlanCard extends StatefulWidget {
  const MedPlanCard({required this.draft, required this.onChanged, super.key, this.onRemove});
  final MedPlanDraft draft;
  final ValueChanged<MedPlanDraft> onChanged;

  /// Shows the remove button when set (more than one med in a prescription).
  final VoidCallback? onRemove;

  @override
  State<MedPlanCard> createState() => _MedPlanCardState();
}

class _MedPlanCardState extends State<MedPlanCard> {
  late final _name = TextEditingController(text: widget.draft.name);
  late final _dose = TextEditingController(text: widget.draft.dose);
  late final _notes = TextEditingController(text: widget.draft.notes);
  late final _freqN = TextEditingController(text: widget.draft.freqN);
  late final _freqOther = TextEditingController(text: widget.draft.freqOther);
  late final _durN = TextEditingController(text: widget.draft.durN);
  late final _durOther = TextEditingController(text: widget.draft.durOther);

  @override
  void dispose() {
    for (final c in [_name, _dose, _notes, _freqN, _freqOther, _durN, _durOther]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final m = s.strings.meds;
    final d = widget.draft;
    final onChanged = widget.onChanged;
    final onRemove = widget.onRemove;
    return PCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(14),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Input(controller: _name, hint: m.rx_med_name_ph, onChanged: (v) => onChanged(d.copyWith(name: v))),
              const SizedBox(height: 12),
              _Input(controller: _dose, hint: m.rx_med_dose_ph, onChanged: (v) => onChanged(d.copyWith(dose: v))),
              const SizedBox(height: 12),
              _Input(
                controller: _notes,
                hint: m.rx_med_desc_ph,
                onChanged: (v) => onChanged(d.copyWith(notes: v)),
                lines: 2,
              ),
              const SizedBox(height: 12),
              _FieldLabel(m.rx_frequency),
              Row(
                children: [
                  Expanded(
                    child: SelectField<String>(
                      value: d.freqType,
                      items: [
                        ('once', m.freq_once),
                        ('per_day', m.freq_per_day),
                        ('every_x', m.freq_every_x),
                        ('other', m.freq_other),
                      ],
                      onChanged: (v) => onChanged(d.copyWith(freqType: v).synced()),
                    ),
                  ),
                  if (d.freqType == 'per_day' || d.freqType == 'every_x') ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 64,
                      child: _Input(
                        controller: _freqN,
                        number: true,
                        onChanged: (v) => onChanged(d.copyWith(freqN: v).synced()),
                      ),
                    ),
                  ],
                  if (d.freqType == 'every_x') ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: SelectField<String>(
                        value: d.freqUnit,
                        items: [('hours', m.unit_hours), ('days', m.unit_days)],
                        onChanged: (v) => onChanged(d.copyWith(freqUnit: v).synced()),
                      ),
                    ),
                  ],
                ],
              ),
              if (d.freqType == 'other') ...[
                const SizedBox(height: 8),
                _Input(
                  controller: _freqOther,
                  hint: m.freq_other_ph(s.gender),
                  onChanged: (v) => onChanged(d.copyWith(freqOther: v)),
                ),
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
                onChanged: (v) => onChanged(d.copyWith(durType: v)),
              ),
              if (d.durType == 'period') ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    SizedBox(
                      width: 64,
                      child: _Input(
                        controller: _durN,
                        hint: '1',
                        number: true,
                        onChanged: (v) => onChanged(d.copyWith(durN: v)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SelectField<String>(
                        value: d.durUnit,
                        items: [('days', m.unit_days), ('weeks', m.unit_weeks), ('months', m.unit_months)],
                        onChanged: (v) => onChanged(d.copyWith(durUnit: v)),
                      ),
                    ),
                  ],
                ),
              ],
              if (d.durType == 'other') ...[
                const SizedBox(height: 8),
                _Input(
                  controller: _durOther,
                  hint: m.dur_other_ph(s.gender),
                  onChanged: (v) => onChanged(d.copyWith(durOther: v)),
                ),
              ],
              const SizedBox(height: 14),
              _Timing(draft: d, onChanged: onChanged),
            ],
          ),
          if (onRemove != null)
            PositionedDirectional(
              top: 0,
              end: 0,
              child: Material(
                color: AppColors.ink50,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onRemove,
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: Semantics(
                      label: s.strings.common.a11y_close,
                      child: const Icon(LucideIcons.x, size: 13, color: AppColors.textTertiary),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// When the doses happen: Morning/Evening for one dose a day (the design's
/// segmented control), editable time chips for several, or the first dose of an
/// hourly interval.
class _Timing extends StatelessWidget {
  const _Timing({required this.draft, required this.onChanged});
  final MedPlanDraft draft;
  final ValueChanged<MedPlanDraft> onChanged;

  Future<void> _pick(BuildContext context, int i) async {
    final parts = draft.times[i].split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
    );
    // The sheet may have closed while the picker was up.
    if (picked == null || !context.mounted) return;
    onChanged(
      draft.withTime(i, '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final m = s.strings.meds;
    return switch (draft.timing) {
      MedTiming.halfOfDay => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FieldLabel(m.med_when, strong: true),
            Row(
              children: [
                for (final (evening, icon, label) in [
                  (false, LucideIcons.sunrise, m.morning),
                  (true, LucideIcons.moon, m.evening),
                ]) ...[
                  if (evening) const SizedBox(width: 8),
                  Expanded(
                    child: _Choice(
                      selected: draft.evening == evening,
                      icon: icon,
                      label: label,
                      onTap: () => onChanged(draft.copyWith(evening: evening)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      MedTiming.times || MedTiming.firstDose => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FieldLabel(draft.timing == MedTiming.times ? m.med_dose_times : m.med_first_dose, strong: true),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...draft.times.indexed.map(
                  (e) => _Choice(
                    selected: true,
                    icon: LucideIcons.clock,
                    label: e.$2,
                    numeric: true,
                    onTap: () => _pick(context, e.$1),
                  ),
                ),
              ],
            ),
          ],
        ),
    };
  }
}

/// A 44px option button, accent-washed when selected (AddMedSheet `seg`).
class _Choice extends StatelessWidget {
  const _Choice({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
    this.numeric = false,
  });
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool numeric;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final fg = selected ? s.accent.d : AppColors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      child: Pressable(
        onTap: onTap,
        scale: 0.97,
        child: AnimatedContainer(
          duration: Motion.base,
          curve: Motion.easeOut,
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? s.accent.bg : AppColors.white,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: selected ? s.accent.main : AppColors.border, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 7),
              Text(
                label,
                style: numeric
                    ? Typo.num(size: FontSizes.bodySm, color: fg)
                    : Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: fg),
              ),
            ],
          ),
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
            ? Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: AppColors.textSecondary)
            : Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: AppColors.textTertiary),
      ),
    );
  }
}

OutlineInputBorder _border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.md),
      borderSide: BorderSide(color: color, width: 1.5),
    );

class _Input extends StatelessWidget {
  const _Input({required this.controller, required this.onChanged, this.hint, this.lines = 1, this.number = false});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
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
      onChanged: onChanged,
      style: Typo.body(ar: s.rtl).copyWith(color: AppColors.textPrimary, fontSize: FontSizes.subhead),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: Typo.body(ar: s.rtl).copyWith(color: AppColors.textHint, fontSize: FontSizes.subhead),
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: _border(AppColors.border),
        enabledBorder: _border(AppColors.border),
        focusedBorder: _border(s.accent.main),
      ),
    );
  }
}
