class ClaimHandleRequest {
  const ClaimHandleRequest({required this.handle});
  final String handle;
  Map<String, dynamic> toJson() => {'handle': handle};
}

class ChangeLanguageRequest {
  const ChangeLanguageRequest({required this.preferredLanguage});
  final String preferredLanguage;
  Map<String, dynamic> toJson() => {'preferred_language': preferredLanguage};
}

class ChangeCountryRequest {
  const ChangeCountryRequest({required this.countryCode});
  final String countryCode;
  Map<String, dynamic> toJson() => {'country_code': countryCode};
}
