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
