import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../application/use_cases/add_medication_use_case.dart';
import '../../domain/aggregates/medication.dart';
import '../../domain/value_objects/ids.dart';
import '../i18n/i18n.dart';
import '../providers/medication_draft.dart';

/// Form to add a new medication: name, dose, schedule type (segmented),
/// reminder times, start/end dates, and a controlled-substance toggle.
class AddMedicationScreen extends ConsumerStatefulWidget {
  const AddMedicationScreen({super.key});

  @override
  ConsumerState<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends ConsumerState<AddMedicationScreen> {
  final _nameCtrl = TextEditingController();
  final _doseCtrl = TextEditingController();

  /// This form's draft key: a second open form gets its own draft.
  final _form = Object();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _doseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = ref.watch(medicationsStringsProvider);
    // Also keeps the draft alive while sections scroll out of the list.
    final nameMissing = ref.watch(medicationDraftProvider(_form).select((d) => d.nameMissing));
    return Scaffold(
      backgroundColor: AppColors.cream50,
      appBar: AppBar(
        title: Text(m.add),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          BalsmTextField(
            label: m.fieldName,
            controller: _nameCtrl,
            hint: m.fieldNameHint,
            errorText: nameMissing ? m.nameRequired : null,
          ),
          const SizedBox(height: 16),
          BalsmTextField(
            label: m.fieldDose,
            controller: _doseCtrl,
            hint: m.fieldDoseHint,
          ),
          const SizedBox(height: 24),
          _ScheduleSection(form: _form),
          const SizedBox(height: 24),
          _TimesSection(form: _form),
          const SizedBox(height: 16),
          _DatesSection(form: _form),
          const SizedBox(height: 8),
          _ControlledSwitch(form: _form),
          const SizedBox(height: 24),
          BalsmButton(
            label: m.saveMedication,
            loading: _saving,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final m = ref.read(medicationsStringsProvider);
    final name = _nameCtrl.text.trim();
    if (!ref.read(medicationDraftProvider(_form).notifier).validate(name)) return;
    final draft = ref.read(medicationDraftProvider(_form));
    if (!draft.daysValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(m.selectDay)),
      );
      return;
    }

    setState(() => _saving = true);

    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      setState(() => _saving = false);
      return;
    }
    final daily = draft.scheduleType == ScheduleType.daily;
    final medication = Medication(
      id: MedicationId.uuid(),
      userId: userId,
      name: name,
      doseAmount: _doseCtrl.text.trim().isEmpty ? null : _doseCtrl.text.trim(),
      scheduleType: draft.scheduleType,
      scheduleConfig: ScheduleConfig(
        times: draft.sortedTimes,
        days: daily ? null : (draft.days.toList()..sort()),
      ),
      startDate: draft.startDate,
      endDate: draft.endDate,
      isControlled: draft.isControlled,
    );

    try {
      await ref.read(addMedicationUseCaseProvider(userId)).call(medication);
      if (!mounted) return;
      context.goNamed('medications.list');
    } on Object catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(m.saveError)),
      );
    }
  }
}

/// Schedule type, and the weekdays for a schedule that is not daily.
class _ScheduleSection extends ConsumerWidget {
  const _ScheduleSection({required this.form});
  final Object form;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(medicationsStringsProvider);
    final (:scheduleType, :days) =
        ref.watch(medicationDraftProvider(form).select((d) => (scheduleType: d.scheduleType, days: d.days)));
    final draft = ref.read(medicationDraftProvider(form).notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Label(m.schedule),
        const SizedBox(height: 8),
        BalsmSegmented<ScheduleType>(
          options: const [
            ScheduleType.daily,
            ScheduleType.weekly,
            ScheduleType.custom,
          ],
          labelOf: (t) => switch (t) {
            ScheduleType.daily => m.scheduleDaily,
            ScheduleType.weekly => m.scheduleWeekly,
            ScheduleType.custom => m.scheduleCustom,
            // Not offered by this screen's options above.
            ScheduleType.once || ScheduleType.everyHours || ScheduleType.everyDays => '',
          },
          selected: scheduleType,
          onChanged: draft.setSchedule,
        ),
        if (scheduleType != ScheduleType.daily) ...[
          const SizedBox(height: 16),
          _DayPicker(selected: days, onToggle: draft.toggleDay),
        ],
      ],
    );
  }
}

/// Reminder times: edit, remove (never the last), add.
class _TimesSection extends ConsumerWidget {
  const _TimesSection({required this.form});
  final Object form;

  Future<void> _addTime(BuildContext context, WidgetRef ref) async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked == null || !context.mounted) return;
    ref.read(medicationDraftProvider(form).notifier).addTime(picked);
  }

  Future<void> _editTime(BuildContext context, WidgetRef ref, int index, TimeOfDay current) async {
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked == null || !context.mounted) return;
    ref.read(medicationDraftProvider(form).notifier).replaceTime(index, picked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(medicationsStringsProvider);
    final times = ref.watch(medicationDraftProvider(form).select((d) => d.times));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(m.reminderTimes),
        const SizedBox(height: 8),
        for (final (i, time) in times.indexed)
          _TimeRow(
            time: time,
            onEdit: () => unawaited(_editTime(context, ref, i, time)),
            onRemove: times.length > 1 ? () => ref.read(medicationDraftProvider(form).notifier).removeTime(i) : null,
          ),
        TextButton.icon(
          onPressed: () => unawaited(_addTime(context, ref)),
          icon: const Icon(Icons.add, size: 18),
          label: Text(m.addTime),
        ),
      ],
    );
  }
}

/// Start date, and an optional end date that can be cleared.
class _DatesSection extends ConsumerWidget {
  const _DatesSection({required this.form});
  final Object form;

  Future<void> _pickDate(BuildContext context, WidgetRef ref, {required bool isStart}) async {
    final m = ref.read(medicationsStringsProvider);
    final draft = ref.read(medicationDraftProvider(form));
    final picked = await showBalsmDatePicker(
      context,
      initial: isStart ? draft.startDate : (draft.endDate ?? draft.startDate),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      title: isStart ? m.startDate : m.endDate,
      confirmLabel: coreMessagesOf(context).common.confirm,
    );
    if (picked == null || !context.mounted) return;
    final notifier = ref.read(medicationDraftProvider(form).notifier);
    if (isStart) {
      notifier.setStart(picked);
    } else {
      notifier.setEnd(picked);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(medicationsStringsProvider);
    final (:start, :end) =
        ref.watch(medicationDraftProvider(form).select((d) => (start: d.startDate, end: d.endDate)));
    return Column(
      children: [
        _DateRow(
          label: m.startDate,
          value: start,
          onTap: () => unawaited(_pickDate(context, ref, isStart: true)),
        ),
        _DateRow(
          label: m.endDateOptional,
          value: end,
          onTap: () => unawaited(_pickDate(context, ref, isStart: false)),
          onClear: end != null ? () => ref.read(medicationDraftProvider(form).notifier).setEnd(null) : null,
        ),
      ],
    );
  }
}

class _ControlledSwitch extends ConsumerWidget {
  const _ControlledSwitch({required this.form});
  final Object form;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(medicationsStringsProvider);
    final controlled = ref.watch(medicationDraftProvider(form).select((d) => d.isControlled));
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(m.controlledSubstance),
      value: controlled,
      activeThumbColor: AppColors.controlled,
      onChanged: (v) => ref.read(medicationDraftProvider(form).notifier).setControlled(controlled: v),
    );
  }
}

class _DayPicker extends ConsumerWidget {
  const _DayPicker({required this.selected, required this.onToggle});
  final Set<int> selected;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(medicationsStringsProvider);
    // ISO weekdays 1 (Monday) to 7 (Sunday), one initial each.
    final labels = m.dayInitials.split('|').asMap().map((i, label) => MapEntry(i + 1, label));
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: labels.entries.map((e) {
        final active = selected.contains(e.key);
        return GestureDetector(
          onTap: () => onToggle(e.key),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? AppColors.hueBlue : AppColors.ink50,
              shape: BoxShape.circle,
              border: Border.all(
                color: active ? AppColors.hueBlue : AppColors.border,
              ),
            ),
            child: Text(
              e.value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: active ? AppColors.white : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _TimeRow extends ConsumerWidget {
  const _TimeRow({required this.time, required this.onEdit, this.onRemove});
  final TimeOfDay time;
  final VoidCallback onEdit;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(medicationsStringsProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.schedule, size: 18),
              label: Text(time.format(context)),
              style: OutlinedButton.styleFrom(
                alignment: AlignmentDirectional.centerStart,
                foregroundColor: AppColors.textPrimary,
              ),
            ),
          ),
          if (onRemove != null)
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close, size: 18),
              tooltip: m.removeTime,
            ),
        ],
      ),
    );
  }
}

class _DateRow extends ConsumerWidget {
  const _DateRow({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(medicationsStringsProvider);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontSize: FontSizes.description)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: onTap,
            child: Text(
              value == null
                  ? m.dateNotSet
                  : '${value!.year}-${value!.month.toString().padLeft(2, '0')}-${value!.day.toString().padLeft(2, '0')}',
            ),
          ),
          if (onClear != null)
            IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.close, size: 16),
              tooltip: coreMessagesOf(context).common.clear,
            ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: FontSizes.bodySm,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      );
}
