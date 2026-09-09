import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/use_cases/add_medication_use_case.dart';
import '../../domain/aggregates/medication.dart';
import '../../domain/value_objects/ids.dart';

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

  ScheduleType _scheduleType = ScheduleType.daily;
  final List<TimeOfDay> _times = [const TimeOfDay(hour: 8, minute: 0)];
  final Set<int> _days = {1, 2, 3, 4, 5, 6, 7}; // ISO weekdays
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _isControlled = false;
  bool _saving = false;
  String? _nameError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _doseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BalsmColors.cream50,
      appBar: AppBar(
        title: const Text('Add medication'),
        backgroundColor: BalsmColors.surface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          BalsmTextField(
            label: 'Name',
            controller: _nameCtrl,
            hint: 'e.g. Amoxicillin',
            errorText: _nameError,
          ),
          const SizedBox(height: 16),
          BalsmTextField(
            label: 'Dose amount',
            controller: _doseCtrl,
            hint: 'e.g. 500 mg',
          ),
          const SizedBox(height: 24),
          _label('Schedule'),
          const SizedBox(height: 8),
          BalsmSegmented<ScheduleType>(
            options: const [
              ScheduleType.daily,
              ScheduleType.weekly,
              ScheduleType.custom,
            ],
            labelOf: (t) => switch (t) {
              ScheduleType.daily => 'Daily',
              ScheduleType.weekly => 'Weekly',
              ScheduleType.custom => 'Custom',
            },
            selected: _scheduleType,
            onChanged: (t) => setState(() => _scheduleType = t),
          ),
          if (_scheduleType != ScheduleType.daily) ...[
            const SizedBox(height: 16),
            _DayPicker(
              selected: _days,
              onToggle: (d) => setState(() {
                _days.contains(d) ? _days.remove(d) : _days.add(d);
              }),
            ),
          ],
          const SizedBox(height: 24),
          _label('Reminder times'),
          const SizedBox(height: 8),
          ..._times.asMap().entries.map(
                (entry) => _TimeRow(
                  time: entry.value,
                  onEdit: () => _editTime(entry.key),
                  onRemove: _times.length > 1 ? () => setState(() => _times.removeAt(entry.key)) : null,
                ),
              ),
          TextButton.icon(
            onPressed: _addTime,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add time'),
          ),
          const SizedBox(height: 16),
          _DateRow(
            label: 'Start date',
            value: _startDate,
            onTap: () => _pickDate(isStart: true),
          ),
          _DateRow(
            label: 'End date (optional)',
            value: _endDate,
            onTap: () => _pickDate(isStart: false),
            onClear: _endDate != null ? () => setState(() => _endDate = null) : null,
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Controlled substance'),
            value: _isControlled,
            activeThumbColor: BalsmColors.controlled,
            onChanged: (v) => setState(() => _isControlled = v),
          ),
          const SizedBox(height: 24),
          BalsmButton(
            label: 'Save medication',
            loading: _saving,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: BalsmColors.fg2,
        ),
      );

  Future<void> _addTime() async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null) setState(() => _times.add(picked));
  }

  Future<void> _editTime(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _times[index],
    );
    if (picked != null) setState(() => _times[index] = picked);
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : (_endDate ?? _startDate);
    final picked = await showBalsmDatePicker(
      context,
      initial: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      title: isStart ? 'Start date' : 'End date',
      confirmLabel: 'Confirm',
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Name is required');
      return;
    }
    if (_scheduleType != ScheduleType.daily && _days.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one day')),
      );
      return;
    }

    setState(() {
      _saving = true;
      _nameError = null;
    });

    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      setState(() => _saving = false);
      return;
    }
    final medication = Medication(
      id: MedicationId.uuid(),
      userId: userId,
      name: name,
      doseAmount: _doseCtrl.text.trim().isEmpty ? null : _doseCtrl.text.trim(),
      scheduleType: _scheduleType,
      scheduleConfig: ScheduleConfig(
        times: _sortedTimeStrings(),
        days: _scheduleType == ScheduleType.daily ? null : (_days.toList()..sort()),
      ),
      startDate: _startDate,
      endDate: _endDate,
      isControlled: _isControlled,
    );

    try {
      await ref.read(addMedicationUseCaseProvider(userId)).call(medication);
      if (!mounted) return;
      context.goNamed('medications.list');
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save medication')),
      );
    }
  }

  List<String> _sortedTimeStrings() {
    final list = _times.toList()..sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
    return list.map(_hhmm).toList();
  }

  String _hhmm(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class _DayPicker extends StatelessWidget {
  const _DayPicker({required this.selected, required this.onToggle});
  final Set<int> selected;
  final ValueChanged<int> onToggle;

  static const _labels = {
    1: 'M',
    2: 'T',
    3: 'W',
    4: 'T',
    5: 'F',
    6: 'S',
    7: 'S',
  };

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: _labels.entries.map((e) {
          final active = selected.contains(e.key);
          return GestureDetector(
            onTap: () => onToggle(e.key),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? BalsmColors.petalBlue : BalsmColors.ink50,
                shape: BoxShape.circle,
                border: Border.all(
                  color: active ? BalsmColors.petalBlue : BalsmColors.border,
                ),
              ),
              child: Text(
                e.value,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : BalsmColors.fg2,
                ),
              ),
            ),
          );
        }).toList(),
      );
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({required this.time, required this.onEdit, this.onRemove});
  final TimeOfDay time;
  final VoidCallback onEdit;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.schedule, size: 18),
                label: Text(time.format(context)),
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  foregroundColor: BalsmColors.fg1,
                ),
              ),
            ),
            if (onRemove != null)
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Remove time',
              ),
          ],
        ),
      );
}

class _DateRow extends StatelessWidget {
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
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label, style: const TextStyle(fontSize: 14)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: onTap,
              child: Text(
                value == null
                    ? 'Set'
                    : '${value!.year}-${value!.month.toString().padLeft(2, '0')}-${value!.day.toString().padLeft(2, '0')}',
              ),
            ),
            if (onClear != null)
              IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close, size: 16),
                tooltip: 'Clear',
              ),
          ],
        ),
      );
}
