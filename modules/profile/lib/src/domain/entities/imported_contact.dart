import '../value_objects/care_provider_type.dart';
import '../value_objects/ids.dart';
import 'care_provider.dart';

/// Last nine digits of [phone], the identity two spellings of one number share.
///
/// Nine rather than the whole string because the same number is written
/// `+201002345678`, `01002345678` and `+20 100 234 5678` in one address book,
/// and nine digits is short enough to survive every country-code and
/// trunk-prefix variation Balsm ships in while staying long enough not to
/// collide. Empty when there is nothing to compare — a contact with no number
/// is never a duplicate of anything.
String contactPhoneKey(String? phone) {
  final digits = (phone ?? '').replaceAll(RegExp(r'\D'), '');
  return digits.length <= 9 ? digits : digits.substring(digits.length - 9);
}

/// Best guess at what a contact is, from their name alone.
///
/// A starting point the patient corrects in the review sheet, never a
/// classification acted on: the fallback is deliberately [CareProviderType.other]
/// rather than `doctor`, because a personal contact silently filed as a doctor
/// is a wrong record about who treats this patient.
CareProviderType guessCareProviderType(String? name) {
  final n = (name ?? '').trim().toLowerCase();
  if (n.isEmpty) return CareProviderType.other;

  // Prefix-anchored so "Andrew" and "Sandra" are not doctors.
  if (RegExp(r'^(dr\.?\s|د\.|دكتور|doctor\b)').hasMatch(n)) return CareProviderType.doctor;
  if (RegExp(r'pharm|صيدل').hasMatch(n)) return CareProviderType.pharmacy;
  if (RegExp(r'\blab\b|laborator|معمل|مختبر|تحاليل').hasMatch(n)) return CareProviderType.lab;
  if (RegExp(r'nurse|ممرض').hasMatch(n)) return CareProviderType.nurse;
  if (RegExp(r'physio|علاج طبيعي').hasMatch(n)) return CareProviderType.physio;
  if (RegExp(r'clinic|hospital|centre|center|عيادة|مستشفى|مركز').hasMatch(n)) return CareProviderType.clinic;
  if (RegExp(r'carer|caregiver|جليس|مرافق').hasMatch(n)) return CareProviderType.carer;
  return CareProviderType.other;
}

/// One contact the patient picked from the phone's address book, before it
/// becomes a care-team record.
///
/// Deliberately its own type rather than a half-built [CareProvider]: nothing
/// here is persisted until the patient confirms it in the review sheet, and
/// keeping the draft separate means an abandoned import leaves no trace.
class ImportedContact {
  ImportedContact({
    required this.id,
    required this.name,
    required this.phones,
    this.email,
    CareProviderType? type,
  }) : type = type ?? guessCareProviderType(name);

  /// Stable only for the lifetime of the sheet — it is the selection key, never
  /// persisted. The saved row gets a fresh [CareProviderId].
  final String id;

  final String name;

  /// Every number on the contact, in the order the OS returned them. Only the
  /// first two survive into a care provider, which has room for exactly two.
  final List<String> phones;

  final String? email;

  /// Guessed on construction, overridable by the patient.
  final CareProviderType type;

  ImportedContact withType(CareProviderType newType) =>
      ImportedContact(id: id, name: name, phones: phones, email: email, type: newType);

  /// Whether one of [existing] already carries this contact's number, so the
  /// sheet can show it as already on the team instead of offering a duplicate.
  bool isAlreadyOnTeam(Iterable<CareProvider> existing) {
    final key = contactPhoneKey(phones.isEmpty ? null : phones.first);
    if (key.isEmpty) return false;
    return existing.any((p) => contactPhoneKey(p.phone) == key || contactPhoneKey(p.phone2) == key);
  }

  /// The care-team record this contact becomes.
  ///
  /// Only what the address book actually holds is carried over. Specialty,
  /// clinic, address and notes stay null rather than being inferred — the card
  /// says what the patient told it, and an invented clinic is worse than a
  /// blank one.
  CareProvider toCareProvider(HealthProfileId profileId, {required DateTime createdAt}) {
    String? at(int i) {
      if (phones.length <= i) return null;
      final v = phones[i].trim();
      return v.isEmpty ? null : v;
    }

    final cleanEmail = email?.trim();

    return CareProvider(
      id: const CareProviderId.empty(),
      healthProfileId: profileId,
      type: type,
      name: name.trim(),
      phone: at(0),
      phone2: at(1),
      email: (cleanEmail == null || cleanEmail.isEmpty) ? null : cleanEmail,
      createdAt: createdAt,
    );
  }
}
