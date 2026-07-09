import 'package:core/core.dart';

/// Emitted when a brand-new user completes sign-up.
/// PHI constraint: userId and email are NOT included in toJson() log payload.
class UserSignedUp extends AppEvent {
  const UserSignedUp({
    required this.userId,
    required this.email,
    required this.provider,
    required this.countryCode,
  });

  /// UUIDv7 user identifier. Not serialised to logs.
  final UserId userId;

  /// Email address. Not serialised to logs.
  final String email;

  /// Identity provider: 'email' | 'google' | 'apple'.
  final String provider;

  /// ISO 3166-1 alpha-2 country code.
  final String countryCode;

  @override
  String get eventName => 'user_signed_up';

  @override
  Map<String, dynamic> toJson() => {
        'provider': provider,
        'country_code': countryCode,
        // userId and email omitted — PHI constraint FR-047
      };
}
