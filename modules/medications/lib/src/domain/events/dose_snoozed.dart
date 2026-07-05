import 'package:core/core.dart';

/// Emitted when a scheduled dose is snoozed until [snoozeUntil].
class DoseSnoozed extends AppEvent {
  const DoseSnoozed({
    required this.doseEventId,
    required this.medicationId,
    required this.scheduledAt,
    required this.recordedAt,
    required this.snoozeUntil,
  });

  final UuidV7 doseEventId;
  final UuidV7 medicationId;
  final DateTime scheduledAt;
  final DateTime recordedAt;
  final DateTime snoozeUntil;

  @override
  String get eventName => 'dose.snoozed';

  @override
  Map<String, dynamic> toJson() => {
        'doseEventId': doseEventId.toString(),
        'medicationId': medicationId.toString(),
        'scheduledAt': scheduledAt.toIso8601String(),
        'recordedAt': recordedAt.toIso8601String(),
        'snoozeUntil': snoozeUntil.toIso8601String(),
      };
}
