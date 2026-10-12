import 'package:core/core.dart';

/// Emitted when an existing user successfully signs in.
/// PHI constraint: userId and email are NOT included in toJson() log payload.
class UserSignedIn extends AppEvent {
  const UserSignedIn({
    required this.userId,
    required this.email,
    required this.provider,
  });

  /// UUIDv7 user identifier. Not serialised to logs.
  final UserId userId;

  /// Email address. Not serialised to logs.
  final String email;

  /// Identity provider: 'email' | 'google' | 'apple'.
  final String provider;

  @override
  String get eventName => 'user_signed_in';

  @override
  Map<String, dynamic> toJson() => {
        'provider': provider,
        // userId and email omitted — PHI constraint FR-047
      };
}
