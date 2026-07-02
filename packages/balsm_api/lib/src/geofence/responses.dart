class DeniedCountriesResponse {
  const DeniedCountriesResponse({this.deniedCodes = const []});

  /// Raw wire values — callers normalize (trim/uppercase) themselves.
  final List<String> deniedCodes;

  factory DeniedCountriesResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['denied_codes'];
    if (raw is! List) return const DeniedCountriesResponse();
    return DeniedCountriesResponse(
      deniedCodes: raw.map((e) => e.toString()).toList(growable: false),
    );
  }
}
