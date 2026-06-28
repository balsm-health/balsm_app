import 'package:core/core.dart';

/// Emitted when a user signs out.
/// PHI constraint: userId is NOT included in toJson() log payload.
class UserSignedOut extends AppEvent {
  const UserSignedOut({required this.userId});

  /// UUIDv7 user identifier. Not serialised to logs.
  final String userId;

  @override
  String get eventName => 'user_signed_out';

  @override
  Map<String, dynamic> toJson() => {
        // userId omitted — PHI constraint FR-047
      };
}
