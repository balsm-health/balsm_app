import 'package:flutter/foundation.dart' show immutable, listEquals, setEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;
import 'package:material_ui/material_ui.dart' show TimeOfDay;

import '../../domain/aggregates/medication.dart';

/// What the add-medication form holds besides its two text fields (name and
/// dose stay in their controllers): the schedule, reminder times, dates and
/// the controlled-substance flag. PHI, so its provider is auto-disposed and
/// keyed per form: the draft is gone when the form closes.
@immutable
class MedicationDraft {
  MedicationDraft({
    required this.startDate,
    this.scheduleType = ScheduleType.daily,
    List<TimeOfDay> times = const [TimeOfDay(hour: 8, minute: 0)],
    Set<int> days = const {1, 2, 3, 4, 5, 6, 7},
    this.endDate,
    this.isControlled = false,
    this.nameMissing = false,
  })  : times = List.unmodifiable(times),
        days = Set.unmodifiable(days);

  final ScheduleType scheduleType;

  /// Reminder times in the order they were added.
  final List<TimeOfDay> times;

  /// ISO weekdays, 1 (Monday) to 7 (Sunday); used when the schedule is not daily.
  final Set<int> days;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isControlled;

  /// Save was pressed with an empty name.
  final bool nameMissing;

  /// A non-daily schedule needs at least one day.
  bool get daysValid => scheduleType == ScheduleType.daily || days.isNotEmpty;

  /// The reminder times, earliest first, as `HH:mm`.
  List<String> get sortedTimes {
    final sorted = [...times]..sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
    return [for (final t in sorted) '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}'];
  }

  MedicationDraft _copy({
    ScheduleType? scheduleType,
    List<TimeOfDay>? times,
    Set<int>? days,
    DateTime? startDate,
    DateTime? Function()? endDate,
    bool? isControlled,
    bool? nameMissing,
  }) =>
      MedicationDraft(
        scheduleType: scheduleType ?? this.scheduleType,
        times: times ?? this.times,
        days: days ?? this.days,
        startDate: startDate ?? this.startDate,
        endDate: endDate == null ? this.endDate : endDate(),
        isControlled: isControlled ?? this.isControlled,
        nameMissing: nameMissing ?? this.nameMissing,
      );

  MedicationDraft withSchedule(ScheduleType type) => _copy(scheduleType: type);

  MedicationDraft toggleDay(int day) =>
      _copy(days: days.contains(day) ? ({...days}..remove(day)) : {...days, day});

  MedicationDraft addTime(TimeOfDay t) => _copy(times: [...times, t]);

  MedicationDraft replaceTime(int index, TimeOfDay t) =>
      index < 0 || index >= times.length ? this : _copy(times: [...times]..[index] = t);

  /// The last time cannot be removed: a medication needs a reminder.
  MedicationDraft removeTime(int index) =>
      times.length <= 1 || index < 0 || index >= times.length ? this : _copy(times: [...times]..removeAt(index));

  MedicationDraft withStart(DateTime d) => _copy(startDate: d);

  MedicationDraft withEnd(DateTime? d) => _copy(endDate: () => d);

  MedicationDraft withControlled({required bool controlled}) => _copy(isControlled: controlled);

  /// Marks the name as missing, or clears the mark, for [name] as typed.
  MedicationDraft validated(String name) => _copy(nameMissing: name.trim().isEmpty);

  @override
  bool operator ==(Object other) =>
      other is MedicationDraft &&
      other.scheduleType == scheduleType &&
      listEquals(other.times, times) &&
      setEquals(other.days, days) &&
      other.startDate == startDate &&
      other.endDate == endDate &&
      other.isControlled == isControlled &&
      other.nameMissing == nameMissing;

  @override
  int get hashCode => Object.hash(
        scheduleType,
        Object.hashAll(times),
        Object.hashAllUnordered(days),
        startDate,
        endDate,
        isControlled,
        nameMissing,
      );
}

class MedicationDraftNotifier extends Notifier<MedicationDraft> {
  MedicationDraftNotifier(this.form);

  /// The form's identity token; only the family key, never read.
  final Object form;

  @override
  MedicationDraft build() => MedicationDraft(startDate: DateTime.now());

  void setSchedule(ScheduleType type) => state = state.withSchedule(type);
  void toggleDay(int day) => state = state.toggleDay(day);
  void addTime(TimeOfDay t) => state = state.addTime(t);
  void replaceTime(int index, TimeOfDay t) => state = state.replaceTime(index, t);
  void removeTime(int index) => state = state.removeTime(index);
  void setStart(DateTime d) => state = state.withStart(d);
  void setEnd(DateTime? d) => state = state.withEnd(d);
  void setControlled({required bool controlled}) => state = state.withControlled(controlled: controlled);

  /// Checks the typed [name]; true when the draft can be saved.
  bool validate(String name) {
    state = state.validated(name);
    return !state.nameMissing;
  }
}

/// One draft per form instance: the key is a token the form's State creates
/// once, so two open forms never share a draft.
final NotifierProviderFamily<MedicationDraftNotifier, MedicationDraft, Object> medicationDraftProvider =
    NotifierProvider.autoDispose.family<MedicationDraftNotifier, MedicationDraft, Object>(MedicationDraftNotifier.new);
