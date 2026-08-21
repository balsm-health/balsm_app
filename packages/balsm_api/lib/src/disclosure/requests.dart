class AcceptDisclosureRequest {
  const AcceptDisclosureRequest({
    required this.disclosureId,
    required this.version,
    required this.countryCode,
    required this.supervisoryAuthority,
    required this.preferredLanguage,
  });

  final String disclosureId;
  final String version;
  final String countryCode;
  final String supervisoryAuthority;
  final String preferredLanguage;

  Map<String, dynamic> toJson() => {
        'disclosure_id': disclosureId,
        'version': version,
        'country_code': countryCode,
        'supervisory_authority': supervisoryAuthority,
        // Server binds `language` (Disclosure POST /disclosure/accept →
        // AcceptDisclosureRequest.Language), not `preferred_language`.
        'language': preferredLanguage,
      };
}
