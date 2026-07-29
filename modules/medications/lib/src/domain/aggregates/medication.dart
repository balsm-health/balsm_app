import 'package:core/core.dart';

import '../entities/dose_event.dart';
import '../value_objects/ids.dart';

/// How a medication's reminder schedule repeats.
enum ScheduleType { daily, weekly, custom }

/// Schedule configuration for a [Medication].
///
/// [times] are local clock times in `HH:mm` 24-hour format (e.g. `08:00`).
/// [days] is only meaningful for [ScheduleType.weekly] / [ScheduleType.custom]
/// and uses ISO-8601 weekday numbering: 1 = Monday … 7 = Sunday.
class ScheduleConfig {
  const ScheduleConfig({required this.times, this.days});

  /// Local times in `HH:mm` 24-hour format.
  final List<String> times;

  /// ISO-8601 weekdays (1=Mon..7=Sun). Null for daily schedules.
  final List<int>? days;

  ScheduleConfig copyWith({List<String>? times, List<int>? days}) =>
      ScheduleConfig(times: times ?? this.times, days: days ?? this.days);

  Map<String, dynamic> toJson() => {
        'times': times,
        if (days != null) 'days': days,
      };

  factory ScheduleConfig.fromJson(Map<String, dynamic> json) => ScheduleConfig(
        times: (json['times'] as List).map((e) => e as String).toList(),
        days: (json['days'] as List?)?.map((e) => e as int).toList(),
      );

  @override
  bool operator ==(Object other) =>
      other is ScheduleConfig && _listEquals(other.times, times) && _listEquals(other.days, days);

  @override
  int get hashCode => Object.hash(
        Object.hashAll(times),
        days == null ? null : Object.hashAll(days!),
      );
}

bool _listEquals<T>(List<T>? a, List<T>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
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
      );

  @override
  bool operator ==(Object other) => other is Medication && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
