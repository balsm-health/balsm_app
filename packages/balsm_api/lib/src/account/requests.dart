class ClaimHandleRequest {
  const ClaimHandleRequest({required this.handle});
  final String handle;
  Map<String, dynamic> toJson() => {'handle': handle};
}

/// NOTE: the account area uses camelCase wire keys (unlike other areas).
class ChangeLanguageRequest {
  const ChangeLanguageRequest({required this.preferredLanguage});
  final String preferredLanguage;
  Map<String, dynamic> toJson() => {'preferredLanguage': preferredLanguage};
}

class ChangeCountryRequest {
  const ChangeCountryRequest({required this.countryCode});
  final String countryCode;
  Map<String, dynamic> toJson() => {'countryCode': countryCode};
}
