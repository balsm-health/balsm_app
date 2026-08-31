import 'package:core/core.dart';

import '../value_objects/ids.dart';

/// One line on a prescription — a drug and how to take it.
class PrescribedItem {
  const PrescribedItem({required this.name, this.dose});

  final String name;

  /// Free text as written on the script ("500mg · twice daily").
  final String? dose;

  Map<String, dynamic> toJson() => {'name': name, if (dose != null) 'dose': dose};

  static PrescribedItem fromJson(Map<String, dynamic> json) =>
      PrescribedItem(name: json['name'] as String, dose: json['dose'] as String?);

  @override
  bool operator ==(Object other) => other is PrescribedItem && other.name == name && other.dose == dose;

  @override
  int get hashCode => Object.hash(name, dose);
}

/// A prescription the patient holds. PHI, on-device only (SQLCipher).
///
/// Patient-entered from a paper or electronic script — there is no
/// e-prescribing backend to fetch from, and the app does not fabricate
/// clinicians (same stance as `CareTeamScreen`).
class Prescription {
  const Prescription({
    required this.id,
    required this.userId,
    required this.clinician,
    this.specialty,
    this.reference,
    this.items = const [],
    required this.issuedAt,
    this.validUntil,
    required this.createdAt,
  });

  final PrescriptionId id;
  final UserId userId;

  /// Who wrote it, as the patient recorded it.
  final String clinician;

  final String? specialty;

  /// The code a pharmacy scans or types. Rendered as the QR payload.
  final String? reference;

  final List<PrescribedItem> items;
  final DateTime issuedAt;

  /// Null means open-ended — treated as still active.
  final DateTime? validUntil;

  final DateTime createdAt;

  /// Active until its validity date passes. An open-ended script stays active.
  bool isActive([DateTime? now]) {
    final until = validUntil;
    if (until == null) return true;
    return until.isAfter(now ?? DateTime.now());
  }

  Prescription copyWith({
    String? clinician,
    String? specialty,
    String? reference,
    List<PrescribedItem>? items,
    DateTime? issuedAt,
    DateTime? validUntil,
  }) =>
      Prescription(
        id: id,
        userId: userId,
        clinician: clinician ?? this.clinician,
        specialty: specialty ?? this.specialty,
        reference: reference ?? this.reference,
        items: items ?? this.items,
        issuedAt: issuedAt ?? this.issuedAt,
        validUntil: validUntil ?? this.validUntil,
        createdAt: createdAt,
      );

  @override
  bool operator ==(Object other) => other is Prescription && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
