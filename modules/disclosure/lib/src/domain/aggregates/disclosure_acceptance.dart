import '../value_objects/ids.dart';

/// Aggregate root representing a patient's acceptance of a disclosure document.
/// PHI-free: no health data stored.
class DisclosureAcceptance {
  const DisclosureAcceptance({
    required this.disclosureId,
    required this.version,
    required this.countryCodeAtAccept,
    required this.supervisoryAuthorityNameAtAccept,
    required this.preferredLanguageAtAccept,
    required this.acceptedAt,
  });

  final DisclosureId disclosureId;
  final String version;
  final String countryCodeAtAccept;
  final String supervisoryAuthorityNameAtAccept;
  final String preferredLanguageAtAccept;
  final DateTime acceptedAt;

  Map<String, dynamic> toJson() => {
        'disclosure_id': disclosureId.value,
        'version': version,
        'country_code': countryCodeAtAccept,
        'supervisory_authority': supervisoryAuthorityNameAtAccept,
        'preferred_language': preferredLanguageAtAccept,
        'accepted_at': acceptedAt.toIso8601String(),
      };

  factory DisclosureAcceptance.fromJson(Map<String, dynamic> json) => DisclosureAcceptance(
        disclosureId: DisclosureId.value(json['disclosure_id'] as String),
        version: json['version'] as String,
        countryCodeAtAccept: json['country_code'] as String,
        supervisoryAuthorityNameAtAccept: json['supervisory_authority'] as String,
        preferredLanguageAtAccept: json['preferred_language'] as String,
        acceptedAt: DateTime.parse(json['accepted_at'] as String),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DisclosureAcceptance && disclosureId == other.disclosureId && version == other.version;

  @override
  int get hashCode => Object.hash(disclosureId, version);
}
