import '../value_objects/care_provider_type.dart';
import '../value_objects/ids.dart';

/// One member of the patient's care team — a person or a place.
///
/// PHI-adjacent and stored ON-DEVICE ONLY (drift/SQLCipher): who treats a
/// patient is itself sensitive. Every field is patient-entered free text;
/// there is no provider directory to link against and nothing is ever seeded.
class CareProvider {
  const CareProvider({
    required this.id,
    required this.healthProfileId,
    required this.type,
    required this.name,
    this.specialty,
    this.phone,
    this.phone2,
    this.email,
    this.clinic,
    this.address,
    this.mapUrl,
    this.notes,
    required this.createdAt,
  });

  final CareProviderId id;
  final HealthProfileId healthProfileId;
  final CareProviderType type;

  /// The only required field — "Dr. Sara Kamal", or "El Ezaby Pharmacy".
  final String name;

  /// Specialty for a person, services for a place.
  final String? specialty;

  final String? phone;

  /// A second number, typically the clinic landline.
  final String? phone2;

  final String? email;

  /// Clinic or hospital for a person, branch or group for a place.
  final String? clinic;
  final String? address;

  /// A link the patient pasted from their maps app, used for the card's
  /// "Directions" action. Patient-entered like everything else here; it is
  /// only ever opened, never fetched or resolved.
  final String? mapUrl;

  /// Free-text reminder: visiting hours, who referred them.
  final String? notes;

  final DateTime createdAt;

  /// The same provider under the id storage assigned it.
  CareProvider withId(CareProviderId newId) => CareProvider(
        id: newId,
        healthProfileId: healthProfileId,
        type: type,
        name: name,
        specialty: specialty,
        phone: phone,
        phone2: phone2,
        email: email,
        clinic: clinic,
        address: address,
        mapUrl: mapUrl,
        notes: notes,
        createdAt: createdAt,
      );

  /// The one-line location summary the care-team card shows.
  String? get placeLine {
    final parts = [clinic, address].where((p) => p != null && p.isNotEmpty);
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// Only an `http(s)` link is offered as Directions. Anything else the patient
  /// typed stays stored but is not turned into a tappable action — a bare
  /// address is not a destination, and a non-web scheme is not one we launch.
  bool get hasDirections {
    final v = mapUrl?.trim();
    if (v == null || v.isEmpty) return false;
    final uri = Uri.tryParse(v);
    return uri != null && uri.hasAuthority && (uri.scheme == 'http' || uri.scheme == 'https');
  }
}
