import 'package:core/core.dart';

/// Emitted when a user requests account deletion and a grace period begins.
class DeletionRequested extends AppEvent {
  const DeletionRequested({required this.graceUntil});

  final DateTime graceUntil;

  @override
  String get eventName => 'deletion_requested';

  // Note: carries no PHI — only the non-identifying grace deadline.
  @override
  Map<String, dynamic> toJson() => {
        'graceUntil': graceUntil.toUtc().toIso8601String(),
      };
}

/// Emitted when a pending account deletion is cancelled within the grace window.
class DeletionCancelled extends AppEvent {
  const DeletionCancelled();

  @override
  String get eventName => 'deletion_cancelled';

  @override
  Map<String, dynamic> toJson() => const {};
}

/// Emitted when the grace period elapses and the account is permanently purged.
class DeletionPurged extends AppEvent {
  const DeletionPurged();

  @override
  String get eventName => 'deletion_purged';

  @override
  Map<String, dynamic> toJson() => const {};
}
