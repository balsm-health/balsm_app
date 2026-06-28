import 'package:core/core.dart';

/// Emitted when a new medication is added to a user's regimen.
class MedicationAdded extends AppEvent {
  const MedicationAdded({
    required this.medicationId,
    required this.userId,
    required this.name,
    required this.occurredAt,
  });

  final UuidV7 medicationId;
  final String userId;
  final String name;
  final DateTime occurredAt;

  @override
  String get eventName => 'medication.added';

  @override
  Map<String, dynamic> toJson() => {
        'medicationId': medicationId.toString(),
        'userId': userId,
        'name': name,
        'occurredAt': occurredAt.toIso8601String(),
      };
}
