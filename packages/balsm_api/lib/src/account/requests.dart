class ClaimHandleRequest {
  const ClaimHandleRequest({required this.handle});
  final String handle;
  Map<String, dynamic> toJson() => {'handle': handle};
}

class ChangeLanguageRequest {
  const ChangeLanguageRequest({required this.preferredLanguage});
  // Server binds `language` (Account PATCH /account/language → req.Language).
  final String preferredLanguage;
  Map<String, dynamic> toJson() => {'language': preferredLanguage};
}

class ChangeCountryRequest {
  const ChangeCountryRequest({required this.countryCode});
  final String countryCode;
  Map<String, dynamic> toJson() => {'country_code': countryCode};
}

/// PATCH /account/profile. A null field is omitted from the body, so the server
/// leaves it unchanged; pass an empty string to clear a field. `dateOfBirth` is
/// `yyyy-MM-dd`. `dateOfBirth` + `nationalId` are PHI/PII (encrypted at rest).
class UpdateProfileRequest {
  const UpdateProfileRequest({
    this.firstName,
    this.lastName,
    this.bio,
    this.gender,
    this.nationality,
    this.phone,
    this.dateOfBirth,
    this.nationalId,
  });

  // Server derives display_name from these; the client never sends display_name.
  final String? firstName;
  final String? lastName;
  final String? bio;
  final String? gender;
  final String? nationality;
  final String? phone;
  final String? dateOfBirth;
  final String? nationalId;

  Map<String, dynamic> toJson() => {
        if (firstName != null) 'first_name': firstName,
        if (lastName != null) 'last_name': lastName,
        if (bio != null) 'bio': bio,
        if (gender != null) 'gender': gender,
        if (nationality != null) 'nationality': nationality,
        if (phone != null) 'phone': phone,
        if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
        if (nationalId != null) 'national_id': nationalId,
      };
}
