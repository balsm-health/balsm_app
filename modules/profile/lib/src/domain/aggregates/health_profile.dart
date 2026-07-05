import 'package:core/core.dart';

/// Main PHI aggregate for the profile bounded context.
/// PHI is stored ON-DEVICE ONLY via drift/SQLCipher — never sent to the cloud.
class HealthProfile {
  const HealthProfile({
    required this.id,
    required this.userId,
    required this.bloodType,
    required this.allergies,
    required this.conditions,
    required this.emergencyContacts,
    required this.updatedAt,
  });

  final UuidV7 id;

  /// Cloud reference (non-PHI). Used to associate the on-device record
  /// with the authenticated Supabase user — never transmitted with PHI.
  final String userId;

  /// Nullable ABO/Rh blood type. One of:
  /// 'A+'|'A-'|'B+'|'B-'|'AB+'|'AB-'|'O+'|'O-' or null (unknown).
  final String? bloodType;

  /// Up to 50 allergies (validation enforced in use-cases).
  final List<Allergy> allergies;

  final List<ChronicCondition> conditions;

  /// Up to 3 emergency contacts (validation enforced in use-cases).
  final List<EmergencyContact> emergencyContacts;

  final DateTime updatedAt;

  /// Returns true when at least one PHI field is populated.
  bool get hasMinimalInfo => bloodType != null || allergies.isNotEmpty;

  HealthProfile copyWith({
    UuidV7? id,
    String? userId,
    String? bloodType,
    bool clearBloodType = false,
    List<Allergy>? allergies,
    List<ChronicCondition>? conditions,
    List<EmergencyContact>? emergencyContacts,
    DateTime? updatedAt,
  }) {
    return HealthProfile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      bloodType: clearBloodType ? null : (bloodType ?? this.bloodType),
      allergies: allergies ?? this.allergies,
      conditions: conditions ?? this.conditions,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Allergy value within HealthProfile.
class Allergy {
  const Allergy({
    required this.id,
    required this.healthProfileId,
    required this.name,
    required this.severity,
    required this.isControlledSubstance,
    required this.createdAt,
  });

  final UuidV7 id;
  final UuidV7 healthProfileId;

  /// Free text, max 100 chars.
  final String name;

  /// One of 'mild' | 'moderate' | 'severe'.
  final String severity;

  final bool isControlledSubstance;
  final DateTime createdAt;
}

/// Chronic condition value within HealthProfile.
class ChronicCondition {
  const ChronicCondition({
    required this.id,
    required this.healthProfileId,
    required this.name,
    required this.createdAt,
  });

  final UuidV7 id;
  final UuidV7 healthProfileId;
  final String name;
  final DateTime createdAt;
}

/// Emergency contact value within HealthProfile.
class EmergencyContact {
  const EmergencyContact({
    required this.id,
    required this.healthProfileId,
    required this.name,
    required this.phone,
    required this.relation,
    required this.isPrimary,
    required this.createdAt,
  });

  final UuidV7 id;
  final UuidV7 healthProfileId;
  final String name;

  /// Phone stored in Western Arabic digits (FR-213 normalization applied on input).
  final String phone;

  final String? relation;
  final bool isPrimary;
  final DateTime createdAt;
}

/// Valid blood type codes (null means unknown/not set).
const List<String> kBloodTypes = [
  'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-',
];

/// Valid allergy severity levels.
const List<String> kAllergySeverities = ['mild', 'moderate', 'severe'];
