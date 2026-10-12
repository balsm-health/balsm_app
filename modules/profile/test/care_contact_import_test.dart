import 'package:flutter_test/flutter_test.dart';
import 'package:profile/profile.dart';

/// Importing a phone contact into the care team (design: `care-import.jsx`).
///
/// The guess is a starting point the patient corrects in the review sheet, not a
/// classification we act on — a wrong guess costs one tap, never a wrong record.
void main() {
  group('type guess', () {
    test('an English doctor prefix guesses doctor', () {
      expect(guessCareProviderType('Dr. Sara Kamal'), CareProviderType.doctor);
      expect(guessCareProviderType('dr Hany Fawzy'), CareProviderType.doctor);
      expect(guessCareProviderType('Doctor Omar'), CareProviderType.doctor);
    });

    test('an Arabic doctor prefix guesses doctor', () {
      expect(guessCareProviderType('د. أحمد منصور'), CareProviderType.doctor);
      expect(guessCareProviderType('دكتور خالد'), CareProviderType.doctor);
    });

    test('pharmacies, labs, nurses, physios and clinics are recognised in both languages', () {
      expect(guessCareProviderType('El Ezaby Pharmacy'), CareProviderType.pharmacy);
      expect(guessCareProviderType('صيدلية الشفاء'), CareProviderType.pharmacy);
      expect(guessCareProviderType('Alfa Lab — Maadi'), CareProviderType.lab);
      expect(guessCareProviderType('معمل التحاليل'), CareProviderType.lab);
      expect(guessCareProviderType('Nurse Mona Adel'), CareProviderType.nurse);
      expect(guessCareProviderType('ممرضة منى'), CareProviderType.nurse);
      expect(guessCareProviderType('Physio Karim Nabil'), CareProviderType.physio);
      expect(guessCareProviderType('علاج طبيعي'), CareProviderType.physio);
      expect(guessCareProviderType('Cleopatra Hospital'), CareProviderType.clinic);
      expect(guessCareProviderType('عيادة المعادي'), CareProviderType.clinic);
    });

    test('an ordinary name falls back to other rather than guessing doctor', () {
      // The fallback must never be a clinical role: "Omar Hassan" silently filed
      // as a doctor is a wrong record about who treats this patient.
      expect(guessCareProviderType('Omar Hassan'), CareProviderType.other);
      expect(guessCareProviderType('أمي'), CareProviderType.other);
      expect(guessCareProviderType(''), CareProviderType.other);
    });

    test('a name merely containing "dr" is not a doctor', () {
      // "Andrew" and "Sandra" contain "dr"; only a prefix counts.
      expect(guessCareProviderType('Andrew Fahmy'), CareProviderType.other);
      expect(guessCareProviderType('Sandra Nabil'), CareProviderType.other);
    });
  });

  group('phone identity', () {
    test('two spellings of one number match on the last nine digits', () {
      expect(contactPhoneKey('+201002345678'), contactPhoneKey('01002345678'));
      expect(contactPhoneKey('+20 100 234 5678'), contactPhoneKey('01002345678'));
    });

    test('different numbers do not match', () {
      expect(contactPhoneKey('+201002345678'), isNot(contactPhoneKey('+201112223333')));
    });

    test('a contact with no number has no key', () {
      expect(contactPhoneKey(''), isEmpty);
      expect(contactPhoneKey(null), isEmpty);
    });
  });

  group('mapping a contact to a care provider', () {
    const profileId = HealthProfileId.value('hp-1');

    test('name, both numbers and email carry over; nothing is invented', () {
      final draft = ImportedContact(
        id: 'c1',
        name: 'Dr. Sara Kamal',
        phones: const ['+201002345678', '+20223584400'],
        email: 'sara.kamal@example.test',
      );

      final provider = draft.toCareProvider(profileId, createdAt: DateTime.utc(2026, 9, 24));

      expect(provider.name, 'Dr. Sara Kamal');
      expect(provider.type, CareProviderType.doctor);
      expect(provider.phone, '+201002345678');
      expect(provider.phone2, '+20223584400');
      expect(provider.email, 'sara.kamal@example.test');
      // The design leaves these for the patient to fill in later.
      expect(provider.specialty, isNull);
      expect(provider.clinic, isNull);
      expect(provider.address, isNull);
      expect(provider.notes, isNull);
      expect(provider.healthProfileId, profileId);
    });

    test('a single number leaves phone2 empty', () {
      final draft = ImportedContact(id: 'c2', name: 'El Ezaby Pharmacy', phones: const ['+20219600']);

      final provider = draft.toCareProvider(profileId, createdAt: DateTime.utc(2026, 9, 24));

      expect(provider.phone, '+20219600');
      expect(provider.phone2, isNull);
      expect(provider.email, isNull);
    });

    test('a corrected type overrides the guess', () {
      final draft = ImportedContact(id: 'c3', name: 'Omar Hassan', phones: const ['+201283004455'])
          .withType(CareProviderType.carer);

      expect(draft.toCareProvider(profileId, createdAt: DateTime.utc(2026, 9, 24)).type, CareProviderType.carer);
    });

    test('the name is trimmed', () {
      final draft = ImportedContact(id: 'c4', name: '  Nurse Mona Adel  ', phones: const ['+201114092231']);

      expect(draft.toCareProvider(profileId, createdAt: DateTime.utc(2026, 9, 24)).name, 'Nurse Mona Adel');
    });
  });

  group('already on the team', () {
    test('a contact whose number is already a provider is flagged, not re-added', () {
      final existing = [
        CareProvider(
          id: const CareProviderId.value('cp-1'),
          healthProfileId: const HealthProfileId.value('hp-1'),
          type: CareProviderType.doctor,
          name: 'Dr. Sara Kamal',
          phone: '01002345678',
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      ];
      final draft = ImportedContact(id: 'c1', name: 'Dr. Sara Kamal', phones: const ['+201002345678']);

      expect(draft.isAlreadyOnTeam(existing), isTrue);
    });

    test('a new contact is not flagged', () {
      final existing = <CareProvider>[];
      final draft = ImportedContact(id: 'c1', name: 'Dr. Sara Kamal', phones: const ['+201002345678']);

      expect(draft.isAlreadyOnTeam(existing), isFalse);
    });

    test('a contact with no number is never treated as a duplicate', () {
      final existing = [
        CareProvider(
          id: const CareProviderId.value('cp-1'),
          healthProfileId: const HealthProfileId.value('hp-1'),
          type: CareProviderType.other,
          name: 'Someone',
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      ];
      final draft = ImportedContact(id: 'c2', name: 'No Number', phones: const []);

      expect(draft.isAlreadyOnTeam(existing), isFalse);
    });
  });
}
