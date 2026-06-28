import 'package:core/core.dart';

/// Domain event emitted when a patient from a geofence-blocked country attempts
/// to sign up.
///
/// PHI-free: country code is not personal health information.
class BlockedSignupAttempted extends AppEvent {
  const BlockedSignupAttempted({
    required this.countryCode,
    required this.source,
  });

  /// ISO-3166 alpha-2 country code that triggered the block.
  final String countryCode;

  /// Where the block was detected: `'country_picker'` | `'auth_gate'`.
  final String source;

  @override
  String get eventName => 'blocked_signup_attempted';

  @override
  Map<String, dynamic> toJson() => {
        'country_code': countryCode,
        'source': source,
      };
}
