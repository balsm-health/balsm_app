import 'dart:convert';

import 'package:cryptography/cryptography.dart' show Sha256;

/// One emergency contact on a shared card.
class CardContact {
  const CardContact({required this.name, required this.phone, this.relation});

  final String name;
  final String phone;
  final String? relation;

  Map<String, dynamic> toJson() => {'name': name, 'phone': phone, if (relation != null) 'relation': relation};

  factory CardContact.fromJson(Map<String, dynamic> json) => CardContact(
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        relation: json['relation'] as String?,
      );
}

/// The emergency card an account holder may share with a linked member:
/// their own name, date of birth, blood type, allergies, chronic conditions
/// and emergency contacts. PHI — it only ever exists in readable form on the
/// owner's phone and, once opened, on the viewer's. Never log it.
class EmergencyCardPayload {
  const EmergencyCardPayload({
    this.name,
    this.dateOfBirth,
    this.bloodType,
    this.allergies = const [],
    this.conditions = const [],
    this.contacts = const [],
  });

  /// Schema version of the plaintext, inside the ciphertext.
  static const schema = 1;

  final String? name;

  /// Calendar date, `yyyy-MM-dd`.
  final String? dateOfBirth;

  /// ABO/Rh code (`A+`, `O-`, …), or null when unknown.
  final String? bloodType;
  final List<String> allergies;
  final List<String> conditions;
  final List<CardContact> contacts;

  DateTime? get dateOfBirthDay {
    final raw = dateOfBirth;
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Map<String, dynamic> toJson() => {
        'v': schema,
        'name': name,
        'dob': dateOfBirth,
        'blood': bloodType,
        'allergies': allergies,
        'conditions': conditions,
        'contacts': [for (final c in contacts) c.toJson()],
      };

  /// Null when [json] is not a card of a schema this build understands.
  static EmergencyCardPayload? tryFromJson(Map<String, dynamic> json) {
    if (json['v'] != schema) return null;
    return EmergencyCardPayload(
      name: json['name'] as String?,
      dateOfBirth: json['dob'] as String?,
      bloodType: json['blood'] as String?,
      allergies: [for (final a in json['allergies'] as List? ?? const []) a as String],
      conditions: [for (final c in json['conditions'] as List? ?? const []) c as String],
      contacts: [
        for (final c in json['contacts'] as List? ?? const []) CardContact.fromJson(c as Map<String, dynamic>)
      ],
    );
  }

  /// The plaintext the card is sealed from; also what [fingerprint] is taken over.
  String encode() => jsonEncode(toJson());

  /// Changes whenever any field on the card does — how the owner's phone knows
  /// a shared card is stale. A SHA-256 over [encode], kept only on the device.
  Future<String> fingerprint() async {
    final digest = await Sha256().hash(utf8.encode(encode()));
    return base64Url.encode(digest.bytes);
  }
}
