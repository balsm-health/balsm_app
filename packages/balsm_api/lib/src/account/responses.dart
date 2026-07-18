/// PHI rule: this payload carries no PHI — do not add fields like
/// date_of_birth here.
class AccountSelfResponse {
  const AccountSelfResponse({
    required this.id,
    this.handle,
    this.displayName,
    required this.countryCode,
    required this.preferredLanguage,
    this.deletionState = 'ACTIVE',
  });

  final String id;
  final String? handle;
  final String? displayName;
  final String countryCode;
  final String preferredLanguage;

  /// 'ACTIVE' | 'DELETION_REQUESTED' | 'DELETION_CANCELLED'.
  final String deletionState;

  factory AccountSelfResponse.fromJson(Map<String, dynamic> json) =>
      AccountSelfResponse(
        id: json['id'] as String,
        handle: json['handle'] as String?,
        displayName: json['display_name'] as String?,
        countryCode: json['country_code'] as String,
        preferredLanguage: json['preferred_language'] as String,
        deletionState: (json['deletion_state'] as String?) ?? 'ACTIVE',
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
