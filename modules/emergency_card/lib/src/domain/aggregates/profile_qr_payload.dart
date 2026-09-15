import 'dart:convert';

/// Encrypted payload of the profile QR (emergency-token spec v2.0, schema v1).
///
/// Identity only — no medical fields in v1; a future opt-in emergency data set
/// is a v2 payload behind the same version gate. All identity fields are
/// nullable: an empty account profile still mints a valid identity token.
///
/// `v` and `kind` live INSIDE the AES-GCM-authenticated payload so a tampered
/// plaintext envelope cannot change how a decrypted payload is interpreted.
/// Serialised as snake_case JSON to match the platform's API conventions.
///
/// Contains identity PHI (name, DOB) — never log, never write to disk.
class ProfileQrPayload {
  const ProfileQrPayload({
    this.name,
    this.dateOfBirth,
    this.gender,
    required this.lang,
    required this.createdAt,
  });

  static const int schemaVersion = 1;
  static const String kindProfile = 'profile';

  final String? name;

  /// ISO date (yyyy-MM-dd), no time component.
  final String? dateOfBirth;

  /// `male` | `female` | `other`.
  final String? gender;

  /// BCP-47 primary tag of the owner's preferred language. Lives in the
  /// encrypted payload — the server no longer stores it in plaintext.
  final String lang;

  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'v': schemaVersion,
        'kind': kindProfile,
        'name': name,
        'date_of_birth': dateOfBirth,
        'gender': gender,
        'lang': lang,
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  String toJsonString() => jsonEncode(toJson());

  /// Parses a decrypted payload. Returns null for a legacy (pre-v2.0)
  /// payload — one without a `v` field — which resolvers must render as a
  /// "re-open your app to refresh this code" hint, never as data.
  static ProfileQrPayload? tryParse(Map<String, dynamic> json) {
    if (json['v'] is! int) return null;
    return ProfileQrPayload(
      name: json['name'] as String?,
      dateOfBirth: json['date_of_birth'] as String?,
      gender: json['gender'] as String?,
      lang: json['lang'] as String? ?? 'en',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  static ProfileQrPayload? tryParseString(String s) {
    try {
      return tryParse(jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
