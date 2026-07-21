/// PHI WARNING: this payload carries PHI/PII — `dateOfBirth` and `nationalId`
/// are field-level-encrypted at rest server-side and decrypted only for the
/// account owner (self). Never log this object, never persist it to disk, and
/// never place its PHI fields into the app-wide `AccountSummary` (which stays
/// PHI-free). It is consumed transiently by the account-details screen only.
class AccountSelfResponse {
  const AccountSelfResponse({
    required this.id,
    this.handle,
    this.displayName,
    this.bio,
    this.gender,
    this.nationality,
    this.phone,
    required this.countryCode,
    required this.preferredLanguage,
    this.deletionState = 'ACTIVE',
    this.dobYear,
    this.dateOfBirth,
    this.nationalId,
  });

  final String id;
  final String? handle;
  final String? displayName;
  final String? bio;
  final String? gender;
  final String? nationality;
  final String? phone;
  final String countryCode;
  final String preferredLanguage;

  /// 'ACTIVE' | 'DELETION_REQUESTED' | 'DELETION_CANCELLED'.
  final String deletionState;

  /// Coarse birth year (non-identifying). PHI-lite.
  final int? dobYear;

  /// PHI: full date of birth, `yyyy-MM-dd`. Decrypted server-side for self.
  final String? dateOfBirth;

  /// PHI/PII: national ID, decrypted server-side for self.
  final String? nationalId;

  factory AccountSelfResponse.fromJson(Map<String, dynamic> json) =>
      AccountSelfResponse(
        // Server sends `user_id` (consistent with verify / the rest of the API).
        id: json['user_id'] as String,
        handle: json['handle'] as String?,
        displayName: json['display_name'] as String?,
        bio: json['bio'] as String?,
        gender: json['gender'] as String?,
        nationality: json['nationality'] as String?,
        phone: json['phone'] as String?,
        countryCode: json['country_code'] as String,
        preferredLanguage: json['preferred_language'] as String,
        deletionState: (json['deletion_state'] as String?) ?? 'ACTIVE',
        dobYear: (json['dob_year'] as num?)?.toInt(),
        dateOfBirth: json['date_of_birth'] as String?,
        nationalId: json['national_id'] as String?,
      );
}

class ClaimHandleResponse {
  const ClaimHandleResponse({this.handle});
  final String? handle;
  factory ClaimHandleResponse.fromJson(Map<String, dynamic> json) =>
      ClaimHandleResponse(handle: json['handle'] as String?);
}

class HandleAvailabilityResponse {
  const HandleAvailabilityResponse({this.available = false});
  final bool available;
  factory HandleAvailabilityResponse.fromJson(Map<String, dynamic> json) =>
      HandleAvailabilityResponse(available: json['available'] as bool? ?? false);
}
