import 'package:core/core.dart';

import '../value_objects/ids.dart';

/// One line on a prescription — a drug and how to take it.
class PrescribedItem {
  const PrescribedItem({required this.name, this.dose, this.notes});

  final String name;

  /// Free text as written on the script ("500mg · twice daily").
  final String? dose;

  /// Optional patient note about this line (not a clinical instruction).
  final String? notes;

  Map<String, dynamic> toJson() => {
        'name': name,
        if (dose != null) 'dose': dose,
        if (notes != null) 'notes': notes,
      };

  static PrescribedItem fromJson(Map<String, dynamic> json) => PrescribedItem(
        name: json['name'] as String,
        dose: json['dose'] as String?,
        notes: json['notes'] as String? ?? json['desc'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is PrescribedItem && other.name == name && other.dose == dose && other.notes == notes;

  @override
  int get hashCode => Object.hash(name, dose, notes);
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
    this.title,
    this.specialty,
    this.reference,
    this.source,
    this.attachmentPath,
    this.attachmentKind,
    this.items = const [],
    required this.issuedAt,
    this.validUntil,
    required this.createdAt,
  });

  final PrescriptionId id;
  final UserId userId;

  /// Who wrote it, as the patient recorded it.
  final String clinician;

  /// Patient-given name for a self-added script.
  final String? title;

  final String? specialty;

  /// The code a pharmacy scans or types. Rendered as the QR payload.
  final String? reference;

  /// `self` for patient-entered scripts; `clinic` when a pharmacy/clinic issued it.
  final String? source;

  /// Encrypted vault relative path, or a pasted URL. Never log this.
  final String? attachmentPath;

  /// `image` | `pdf` | `url`.
  final String? attachmentKind;

  final List<PrescribedItem> items;
  final DateTime issuedAt;

  /// Null means open-ended — treated as still active.
  final DateTime? validUntil;

  final DateTime createdAt;

  /// Patient-entered scripts have no pharmacy QR.
  bool get isSelf {
    if (source == 'clinic') return false;
    if (source == 'self') return true;
    return reference == null || reference!.isEmpty;
  }

  /// Active until its validity date passes. An open-ended script stays active.
  bool isActive([DateTime? now]) {
    final until = validUntil;
    if (until == null) return true;
    return until.isAfter(now ?? DateTime.now());
  }

  Prescription copyWith({
    String? clinician,
    String? title,
    String? specialty,
    String? reference,
    String? source,
    String? attachmentPath,
    String? attachmentKind,
    List<PrescribedItem>? items,
    DateTime? issuedAt,
    DateTime? validUntil,
  }) =>
      Prescription(
        id: id,
        userId: userId,
        clinician: clinician ?? this.clinician,
        title: title ?? this.title,
        specialty: specialty ?? this.specialty,
        reference: reference ?? this.reference,
        source: source ?? this.source,
        attachmentPath: attachmentPath ?? this.attachmentPath,
        attachmentKind: attachmentKind ?? this.attachmentKind,
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
