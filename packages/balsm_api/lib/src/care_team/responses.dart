/// One row from `GET /care-team/providers`. [isDeleted] rows are tombstones —
/// the client applies them as local deletes rather than skipping them.
class CareProviderResponse {
  const CareProviderResponse({
    required this.id,
    required this.healthProfileId,
    required this.type,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.isDeleted,
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

  /// Server-assigned; the last-writer-wins comparison key.
  final DateTime updatedAt;

  final bool isDeleted;
  final String? specialty;
  final String? phone;
  final String? phone2;
  final String? email;
  final String? clinic;
  final String? address;
  final String? mapUrl;
  final String? notes;

  factory CareProviderResponse.fromJson(Map<String, dynamic> json) => CareProviderResponse(
        id: json['id'] as String,
        healthProfileId: json['health_profile_id'] as String,
        type: json['type'] as String,
        name: json['name'] as String,
        specialty: json['specialty'] as String?,
        phone: json['phone'] as String?,
        phone2: json['phone2'] as String?,
        email: json['email'] as String?,
        clinic: json['clinic'] as String?,
        address: json['address'] as String?,
        mapUrl: json['map_url'] as String?,
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
        updatedAt: DateTime.parse(json['updated_at'] as String).toUtc(),
        isDeleted: json['is_deleted'] as bool? ?? false,
      );
}
