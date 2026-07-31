import 'package:core/core.dart';

import '../value_objects/ids.dart';

/// Emitted when a new medication is added to a user's regimen.
class MedicationAdded extends AppEvent {
  const MedicationAdded({
    required this.medicationId,
    required this.userId,
    required this.name,
    required this.occurredAt,
  });

  final MedicationId medicationId;
  final UserId userId;
  final String name;
  final DateTime occurredAt;

  @override
  String get eventName => 'medication.added';

  @override
  Map<String, dynamic> toJson() => {
        'medicationId': medicationId.value,
        'userId': userId.value,
        'name': name,
        'occurredAt': occurredAt.toIso8601String(),
      };
}
