import 'package:core/core.dart';

import '../entities/dose_event.dart';

/// Emitted when a previously recorded dose outcome is corrected.
///
/// [parentEventId] references the original (now superseded) dose event. History
/// stays append-only — the original event is never mutated.
class DoseCorrected extends AppEvent {
  const DoseCorrected({
    required this.doseEventId,
    required this.medicationId,
    required this.parentEventId,
    required this.newOutcome,
    required this.scheduledAt,
    required this.recordedAt,
  });

  final UuidV7 doseEventId;
  final UuidV7 medicationId;
  final UuidV7 parentEventId;
  final DoseOutcome newOutcome;
  final DateTime scheduledAt;
  final DateTime recordedAt;

  @override
  String get eventName => 'dose.corrected';

  @override
  Map<String, dynamic> toJson() => {
        'doseEventId': doseEventId.toString(),
        'medicationId': medicationId.toString(),
        'parentEventId': parentEventId.toString(),
        'newOutcome': newOutcome.name,
        'scheduledAt': scheduledAt.toIso8601String(),
        'recordedAt': recordedAt.toIso8601String(),
      };
}
