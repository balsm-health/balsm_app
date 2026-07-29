import 'dart:convert';

/// Immutable snapshot of a patient's emergency health profile.
/// Serialised as JSON, then AES-256-GCM encrypted into the QR payload.
/// PHI never leaves device unencrypted.
class EmergencyCardSnapshot {
  const EmergencyCardSnapshot({
    this.bloodType,
    this.allergyNames = const [],
    this.conditionNames = const [],
    this.primaryContact,
    required this.createdAt,
  })  : assert(allergyNames.length <= 50, 'Max 50 allergies'),
        assert(conditionNames.length <= 10, 'Max 10 conditions');

  final String? bloodType;

  /// Up to 50 allergy display names.
  final List<String> allergyNames;

  /// Up to 10 condition display names.
  final List<String> conditionNames;

  /// Primary emergency contact (name + phone).
  final ({String name, String phone})? primaryContact;

  final DateTime createdAt;

  bool get hasAnyData =>
      bloodType != null || allergyNames.isNotEmpty || conditionNames.isNotEmpty || primaryContact != null;

  Map<String, dynamic> toJson() => {
        'bloodType': bloodType,
        'allergyNames': allergyNames,
        'conditionNames': conditionNames,
        if (primaryContact != null)
          'primaryContact': {
            'name': primaryContact!.name,
            'phone': primaryContact!.phone,
          },
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  factory EmergencyCardSnapshot.fromJson(Map<String, dynamic> json) {
    final contact = json['primaryContact'] as Map<String, dynamic>?;
    return EmergencyCardSnapshot(
      bloodType: json['bloodType'] as String?,
      allergyNames: (json['allergyNames'] as List<dynamic>? ?? []).map((e) => e as String).toList(),
      conditionNames: (json['conditionNames'] as List<dynamic>? ?? []).map((e) => e as String).toList(),
      primaryContact: contact == null
          ? null
          : (
              name: contact['name'] as String,
              phone: contact['phone'] as String,
            ),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory EmergencyCardSnapshot.fromJsonString(String s) => EmergencyCardSnapshot.fromJson(
        jsonDecode(s) as Map<String, dynamic>,
      );
}
