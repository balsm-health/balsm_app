import 'package:core/core.dart';

import '../value_objects/ids.dart';

/// Emitted when a scheduled dose is recorded as skipped.
class DoseSkipped extends AppEvent {
  const DoseSkipped({
    required this.doseEventId,
    required this.medicationId,
    required this.scheduledAt,
    required this.recordedAt,
  });

  final DoseEventId doseEventId;
  final MedicationId medicationId;
  final DateTime scheduledAt;
  final DateTime recordedAt;

  @override
  String get eventName => 'dose.skipped';

  @override
  Map<String, dynamic> toJson() => {
        'doseEventId': doseEventId.value,
        'medicationId': medicationId.value,
        'scheduledAt': scheduledAt.toIso8601String(),
        'recordedAt': recordedAt.toIso8601String(),
      };
}
