import 'package:core/core.dart';

import '../value_objects/ids.dart';

/// Domain event emitted after the patient successfully accepts a disclosure.
class DisclosureAccepted extends AppEvent {
  const DisclosureAccepted({
    required this.disclosureId,
    required this.version,
    required this.countryCode,
    required this.supervisoryAuthority,
    required this.preferredLanguage,
    required this.acceptedAt,
  });

  final DisclosureId disclosureId;
  final String version;
  final String countryCode;
  final String supervisoryAuthority;
  final String preferredLanguage;
  final DateTime acceptedAt;

  @override
  String get eventName => 'disclosure_accepted';

  @override
  Map<String, dynamic> toJson() => {
        'disclosure_id': disclosureId.value,
        'version': version,
        'country_code': countryCode,
        'supervisory_authority': supervisoryAuthority,
        'preferred_language': preferredLanguage,
        'accepted_at': acceptedAt.toIso8601String(),
      };
}
