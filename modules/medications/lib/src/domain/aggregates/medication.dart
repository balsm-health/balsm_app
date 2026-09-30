import 'package:collection/collection.dart';
import 'package:core/core.dart';

import '../entities/dose_event.dart';
import '../value_objects/ids.dart';

/// How a medication's schedule repeats.
///
/// - [daily]: every day, at each of [ScheduleConfig.times].
/// - [weekly] / [custom]: on [ScheduleConfig.days], at each of the times.
/// - [once]: a single dose, on the start date only.
/// - [everyHours]: every [ScheduleConfig.interval] hours, counted from the
///   first time on the start date (so 8h from 08:00 → 08:00, 16:00, 00:00).
/// - [everyDays]: every [ScheduleConfig.interval] days from the start date,
///   at each of the times.
enum ScheduleType { daily, weekly, custom, once, everyHours, everyDays }

/// How long a medication is taken. Only [period] ends on its own: it is stored
/// as [Medication.endDate]. The others are kept so the patient's own words
/// survive a round trip ("until the pack is finished").
enum DurationKind { ongoing, period, untilEmpty, other }

/// Schedule configuration for a [Medication].
///
/// [times] are local clock times in `HH:mm` 24-hour format (e.g. `08:00`).
/// [days] is only meaningful for [ScheduleType.weekly] / [ScheduleType.custom]
/// and uses ISO-8601 weekday numbering: 1 = Monday … 7 = Sunday.
class ScheduleConfig {
  const ScheduleConfig({
    required this.times,
    this.days,
    this.interval,
    this.frequencyNote,
    this.durationKind = DurationKind.ongoing,
    this.durationNote,
  });

  /// Local times in `HH:mm` 24-hour format.
  final List<String> times;

  /// ISO-8601 weekdays (1=Mon..7=Sun). Null for daily schedules.
  final List<int>? days;

  /// Hours between doses for [ScheduleType.everyHours], days for
  /// [ScheduleType.everyDays]. Null otherwise.
  final int? interval;

  /// The patient's own description when the frequency is "other". Display
  /// only; the schedule itself is [times].
  final String? frequencyNote;

  final DurationKind durationKind;

  /// The patient's own description when [durationKind] is [DurationKind.other].
  final String? durationNote;

  ScheduleConfig copyWith({List<String>? times, List<int>? days}) => ScheduleConfig(
        times: times ?? this.times,
        days: days ?? this.days,
        interval: interval,
        frequencyNote: frequencyNote,
        durationKind: durationKind,
        durationNote: durationNote,
      );

  Map<String, dynamic> toJson() => {
        'times': times,
        if (days != null) 'days': days,
        if (interval != null) 'interval': interval,
        if (frequencyNote != null) 'frequency_note': frequencyNote,
        if (durationKind != DurationKind.ongoing) 'duration': durationKind.name,
        if (durationNote != null) 'duration_note': durationNote,
      };

  /// Rows written before interval/duration existed decode as before: no
  /// interval, ongoing.
  factory ScheduleConfig.fromJson(Map<String, dynamic> json) => ScheduleConfig(
        times: (json['times'] as List).map((e) => e as String).toList(),
        days: (json['days'] as List?)?.map((e) => e as int).toList(),
        interval: json['interval'] as int?,
        frequencyNote: json['frequency_note'] as String?,
        durationKind: DurationKind.values.asNameMap()[json['duration']] ?? DurationKind.ongoing,
        durationNote: json['duration_note'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is ScheduleConfig &&
      const ListEquality<String>().equals(other.times, times) &&
      const ListEquality<int>().equals(other.days, days) &&
      other.interval == interval &&
      other.frequencyNote == frequencyNote &&
      other.durationKind == durationKind &&
      other.durationNote == durationNote;

  @override
  int get hashCode => Object.hash(
        Object.hashAll(times),
        days == null ? null : Object.hashAll(days!),
        interval,
        frequencyNote,
        durationKind,
        durationNote,
      );
}

/// Medication aggregate root.
///
/// PHI — lives on-device only. Dose history is APPEND-ONLY: [DoseEvent]s are
/// never mutated or deleted, only added.
class Medication {
  Medication({
    required this.id,
    required this.userId,
    required this.name,
    this.doseAmount,
    required this.scheduleType,
    required this.scheduleConfig,
    required this.startDate,
    this.endDate,
    this.isControlled = false,
    this.notes,
  });

  final MedicationId id;
  final UserId userId;
  final String name;
  final String? doseAmount;
  final ScheduleType scheduleType;
  final ScheduleConfig scheduleConfig;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isControlled;

  /// Free-text notes from the patient ("with food"). PHI, on-device only.
  final String? notes;

  /// True when an end date is set and has passed (medication no longer active).
  bool isExpired() => endDate != null && DateTime.now().isAfter(endDate!);

  /// Validates the invariants of a dose event before it is appended to history.
  ///
  /// A [DoseOutcome.correction] event must reference the original event it
  /// corrects via [DoseEvent.parentEventId].
  void recordDose(DoseEvent e) {
    if (e.outcome == DoseOutcome.correction && e.parentEventId == null) {
      throw ArgumentError('correction needs parent');
    }
  }

  Medication copyWith({
    String? name,
    String? doseAmount,
    ScheduleType? scheduleType,
    ScheduleConfig? scheduleConfig,
    DateTime? startDate,
    DateTime? endDate,
    bool? isControlled,
    String? notes,
  }) =>
      Medication(
        id: id,
        userId: userId,
        name: name ?? this.name,
        doseAmount: doseAmount ?? this.doseAmount,
        scheduleType: scheduleType ?? this.scheduleType,
        scheduleConfig: scheduleConfig ?? this.scheduleConfig,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        isControlled: isControlled ?? this.isControlled,
        notes: notes ?? this.notes,
      );

  @override
  bool operator ==(Object other) => other is Medication && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
