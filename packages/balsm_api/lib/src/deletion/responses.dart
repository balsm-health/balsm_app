class DeletionIntakeResponse {
  const DeletionIntakeResponse({required this.graceUntil, this.deletionState});

  final DateTime graceUntil;

  /// Wire values: 'ACTIVE' | 'DELETION_REQUESTED' | 'DELETION_CANCELLED'.
  final String? deletionState;

  factory DeletionIntakeResponse.fromJson(Map<String, dynamic> json) => DeletionIntakeResponse(
        graceUntil: DateTime.parse(json['grace_until'] as String).toUtc(),
        deletionState: json['deletion_state'] as String?,
      );
}

class DeletionCancelResponse {
  const DeletionCancelResponse({this.deletionState});

  final String? deletionState;

  factory DeletionCancelResponse.fromJson(Map<String, dynamic> json) =>
      DeletionCancelResponse(deletionState: json['deletion_state'] as String?);
}
