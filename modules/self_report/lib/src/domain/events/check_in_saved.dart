import 'package:core/core.dart';

import '../value_objects/ids.dart';

/// Published after a [CheckIn] is persisted on-device. PHI-free — carries only
/// ids and a timestamp, never symptom/pain/vitals detail.
class CheckInSaved extends AppEvent {
  const CheckInSaved({
    required this.checkInId,
    required this.occurredAt,
  });

  final CheckInId checkInId;
  final DateTime occurredAt;

  @override
  String get eventName => 'checkIn.saved';

  @override
  Map<String, dynamic> toJson() => {
        'checkInId': checkInId.toString(),
        'occurredAt': occurredAt.toIso8601String(),
      };
}
