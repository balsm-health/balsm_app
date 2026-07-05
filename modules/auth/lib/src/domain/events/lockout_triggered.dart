import 'package:core/core.dart';

/// Emitted when too many failed attempts trigger a lockout.
/// PHI constraint: the raw identifier (email) is NOT in toJson() log payload.
class LockoutTriggered extends AppEvent {
  const LockoutTriggered({
    required this.identifier,
    required this.lockedUntil,
  });

  /// Opaque identifier (not the raw email address).
  final String identifier;

  /// UTC timestamp when the lockout expires.
  final DateTime lockedUntil;

  @override
  String get eventName => 'lockout_triggered';

  @override
  Map<String, dynamic> toJson() => {
        'locked_until': lockedUntil.toIso8601String(),
        // identifier (email) omitted — PHI constraint FR-047
      };
}
