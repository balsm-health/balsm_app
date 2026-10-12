import 'package:core/core.dart';

import '../value_objects/ids.dart';

/// Emitted when a scheduled dose is snoozed until [snoozeUntil].
class DoseSnoozed extends AppEvent {
  const DoseSnoozed({
    required this.doseEventId,
    required this.medicationId,
    required this.scheduledAt,
    required this.recordedAt,
    required this.snoozeUntil,
  });

  final DoseEventId doseEventId;
  final MedicationId medicationId;
  final DateTime scheduledAt;
  final DateTime recordedAt;
  final DateTime snoozeUntil;

  @override
  String get eventName => 'dose.snoozed';

  @override
  Map<String, dynamic> toJson() => {
        'doseEventId': doseEventId.value,
        'medicationId': medicationId.value,
        'scheduledAt': scheduledAt.toIso8601String(),
        'recordedAt': recordedAt.toIso8601String(),
        'snoozeUntil': snoozeUntil.toIso8601String(),
      };
}
