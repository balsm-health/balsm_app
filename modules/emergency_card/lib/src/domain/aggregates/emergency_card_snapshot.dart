import 'dart:convert';

import 'package:core/core.dart' show BloodType;

/// Immutable snapshot of a patient's emergency health profile.
/// Serialised as JSON, then AES-256-GCM encrypted into the QR payload.
/// PHI never leaves device unencrypted.
class EmergencyCardSnapshot {
  EmergencyCardSnapshot({
    this.bloodType,
    this.allergyNames = const [],
    this.conditionNames = const [],
    this.primaryContact,
    required this.createdAt,
  }) {
    // Domain invariants — enforced in every build mode, not debug asserts:
    // the sealed payload has a 16 KB ciphertext cap, so unbounded lists are
    // a correctness bug, not a style concern.
    if (allergyNames.length > maxAllergies) {
      throw ArgumentError.value(allergyNames.length, 'allergyNames', 'Max $maxAllergies allergies');
    }
    if (conditionNames.length > maxConditions) {
      throw ArgumentError.value(conditionNames.length, 'conditionNames', 'Max $maxConditions conditions');
    }
  }

  static const maxAllergies = 50;
  static const maxConditions = 10;

  final BloodType? bloodType;

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
        'bloodType': bloodType?.code,
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
      // Legacy payloads carry raw strings; unrecognized → unknown.
      bloodType: BloodType.tryParse(json['bloodType'] as String?),
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
