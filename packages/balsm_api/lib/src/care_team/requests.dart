/// Body of `POST /care-team/providers`. Create and update are one call — the
/// server upserts on [id], so the client never tracks which it is.
class UpsertCareProviderRequest {
  const UpsertCareProviderRequest({
    required this.id,
    required this.healthProfileId,
    required this.type,
    required this.name,
    required this.createdAt,
    this.specialty,
    this.phone,
    this.phone2,
    this.email,
    this.clinic,
    this.address,
    this.mapUrl,
    this.notes,
  });

  final String id;
  final String healthProfileId;
  final String type;
  final String name;
  final DateTime createdAt;
  final String? specialty;
  final String? phone;
  final String? phone2;
  final String? email;
  final String? clinic;
  final String? address;
  final String? mapUrl;
  final String? notes;

  Map<String, dynamic> toJson() => {
        'id': id,
        'health_profile_id': healthProfileId,
        'type': type,
        'name': name,
        'specialty': specialty,
        'phone': phone,
        'phone2': phone2,
        'email': email,
        'clinic': clinic,
        'address': address,
        'map_url': mapUrl,
        'notes': notes,
        'created_at': createdAt.toUtc().toIso8601String(),
      };
}
