import 'package:app/balsm_app/screens/family/growth_draft.dart';
import 'package:app/balsm_app/screens/family/link_scan_draft.dart';
import 'package:app/balsm_app/screens/family/medical_summary_draft.dart';
import 'package:app/balsm_app/screens/family/member_form.dart';
import 'package:app/balsm_app/screens/family/vaccination_draft.dart';
import 'package:app/balsm_app/screens/profile_subscreens.dart' show memberHealthProfileProvider;
import 'package:core/core.dart';
import 'package:emergency_card/emergency_card.dart';
import 'package:family/family.dart';
import 'package:family_link/family_link.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:profile/profile.dart';
import 'package:vaccinations/vaccinations.dart';

/// The family forms' drafts as plain state transitions and notifiers, with
/// no widget involved. Every value is synthetic.
void main() {
  ProviderContainer container([List<Override> overrides = const []]) {
    final c = ProviderContainer(retry: noProviderRetry, overrides: overrides);
    addTearDown(c.dispose);
    return c;
  }

  group('VaccinationDraft', () {
    final today = DateTime(2030, 6, 15);

    test('a new dose opens on dose 1 given today, or on the past-due dose', () {
      expect(VaccinationDraft.from(today: today), VaccinationDraft(dose: 1, given: today));
      expect(VaccinationDraft.from(today: today, dose: 3).dose, 3);
    });

    test('an edit opens on the stored dose', () {
      final stored = VaccinationRecord(
        id: const VaccinationRecordId.value('vac-1'),
        vaccine: 'Test vaccine',
        doseNumber: 2,
        administeredOn: DateTime(2030),
        nextDueOn: DateTime(2030, 3),
        createdAt: DateTime(2030),
      );
      final d = VaccinationDraft.from(today: today, editing: stored, dose: 5);
      expect((d.dose, d.given, d.next), (2, DateTime(2030), DateTime(2030, 3)));
    });

    test('moving the day given past the next due day drops the next due day', () {
      final d = VaccinationDraft(dose: 1, given: DateTime(2030), next: DateTime(2030, 2));
      expect(d.withGiven(DateTime(2030, 1, 20)).next, DateTime(2030, 2));
      expect(d.withGiven(DateTime(2030, 2)).next, isNull, reason: 'a next due day must be after the day given');
    });

    test('validity follows the record rules with the typed name', () {
      final d = VaccinationDraft(dose: 1, given: DateTime(2030));
      expect(d.violations(vaccine: '', clinic: '', now: today), isNotEmpty);
      expect(d.violations(vaccine: 'Test vaccine', clinic: '', now: today), isEmpty);
      expect(d.withDose(0).violations(vaccine: 'Test vaccine', clinic: '', now: today), isNotEmpty);
    });

    test('the notifier keeps one draft per form token', () {
      final c = container();
      final a = (form: Object(), editing: null, dose: null);
      final b = (form: Object(), editing: null, dose: null);
      c.read(vaccinationDraftProvider(a).notifier).setDose(4);
      expect(c.read(vaccinationDraftProvider(a)).dose, 4);
      expect(c.read(vaccinationDraftProvider(b)).dose, 1);
    });
  });

  group('GrowthDraft', () {
    final entry = GrowthEntry(
      id: const GrowthEntryId.value('grw-1'),
      measuredOn: DateTime.utc(2020, 2),
      createdAt: DateTime.utc(2020, 2),
      weightKg: 9.5,
    );

    test('editing an entry takes its day; reset adds a new one dated today', () {
      final c = container();
      final form = Object();
      final sub = c.listen(growthDraftProvider(form), (_, __) {});
      c.read(growthDraftProvider(form).notifier).startEdit(entry);
      expect(sub.read().editing, same(entry));
      expect(sub.read().day, DateTime.utc(2020, 2));
      c.read(growthDraftProvider(form).notifier).reset();
      expect(sub.read().editing, isNull);
      expect(sub.read().day.isAfter(DateTime.utc(2020, 2)), isTrue);
    });

    test('a day change keeps the entry being edited', () {
      final d = GrowthDraft.editing(entry).withDay(DateTime(2020, 3));
      expect((d.editing, d.day), (entry, DateTime(2020, 3)));
    });
  });

  group('MedicalSummaryDraft', () {
    const id = HealthProfileId.value('hp-test');
    final at = DateTime(2030);
    HealthProfile profile({BloodType? blood, List<String> allergies = const []}) => HealthProfile(
          id: id,
          userId: const UserId.value('u-test'),
          bloodType: blood,
          allergies: [
            for (final (i, a) in allergies.indexed)
              Allergy(
                id: AllergyId.value('alg-$i'),
                healthProfileId: id,
                name: a,
                severity: 'mild',
                isControlledSubstance: false,
                createdAt: at,
              ),
          ],
          conditions: const [],
          emergencyContacts: const [],
          updatedAt: at,
        );

    test('lists compare by value and cannot be changed in place', () {
      final a = MedicalSummaryDraft(allergies: const ['Test allergy']);
      expect(a, MedicalSummaryDraft(allergies: const ['Test allergy']));
      expect(a, isNot(a.withAllergies(['Test allergy', 'Other'])));
      expect(() => a.allergies.add('x'), throwsUnsupportedError);
    });

    test('the notifier seeds from the stored profile once, then keeps the edits', () async {
      var stored = profile(blood: BloodType.aPositive, allergies: ['Test allergy']);
      final c = container([memberHealthProfileProvider(id).overrideWith((ref) async => stored)]);
      final key = (form: Object(), id: id);
      final sub = c.listen(medicalSummaryDraftProvider(key), (_, __) {});
      expect(sub.read(), isNull, reason: 'nothing to edit until the profile has loaded');
      await c.read(memberHealthProfileProvider(id).future);
      expect(sub.read()?.blood, BloodType.aPositive);
      expect(sub.read()?.allergies, ['Test allergy']);

      c.read(medicalSummaryDraftProvider(key).notifier).setBlood(null);
      stored = profile(blood: BloodType.bNegative);
      c.invalidate(memberHealthProfileProvider(id));
      await c.read(memberHealthProfileProvider(id).future);
      expect(sub.read()?.blood, isNull, reason: 'a reload after a save never overwrites the form');
    });
  });

  group('MedicalSummaryDraft without a stored profile', () {
    const id = HealthProfileId.value('hp-test');

    test('a member with nothing stored still gets an empty draft, so the screen opens', () async {
      final c = container([memberHealthProfileProvider(id).overrideWith((ref) async => null)]);
      final sub = c.listen(medicalSummaryDraftProvider((form: Object(), id: id)), (_, __) {});
      expect(sub.read(), isNull, reason: 'still loading');
      await c.read(memberHealthProfileProvider(id).future);
      expect(sub.read(), MedicalSummaryDraft(), reason: 'null draft would leave the screen blank for good');
    });
  });

  group('MemberForm', () {
    final now = DateTime(2030, 6, 15);

    test('a relation chip that implies a sex sets it; one that does not keeps it', () {
      var f = MemberForm.from(null).withSex(Sex.female);
      f = f.withRelation(Relationship.child, impliedSex: Sex.male);
      expect((f.draft.relationship, f.draft.sex), (Relationship.child, Sex.male));
      f = f.withRelation(Relationship.spouse);
      expect(f.draft.sex, Sex.male);
    });

    test('blood "not sure" is null in the draft but remembered as an answer', () {
      final f = MemberForm.from(null).withBlood(BloodType.oPositive).withBlood(null);
      expect((f.draft.bloodType, f.bloodUnsure), (null, true));
    });

    test('a new group is named only while it is picked', () {
      const group = MemberGroupId.value('grp-test');
      var f = MemberForm.from(null).startNewGroup('Test group');
      expect((f.newGroup, f.draft.newGroupName), (true, 'Test group'));
      f = f.withGroup(group);
      expect((f.newGroup, f.draft.groupId), (false, group));
      expect(f.withNewGroupName('ignored').draft.newGroupName, isNull);
    });

    test('validity is the module draft rules; an adult being added needs consent', () {
      var f = MemberForm.from(null);
      expect(f.canSave(now), isFalse);
      f = f.withName('Test Member').withRelation(Relationship.sibling, impliedSex: Sex.female).withDob(DateTime(2000));
      expect(f.canSave(now), isTrue);
      expect(f.needsConsent(now, editing: false), isTrue);
      expect(f.needsConsent(now, editing: true), isFalse);
      expect(f.toggleConsent().consent, isTrue);
    });

    test('an edit saves the blood type as stored now', () {
      const member = FamilyMember(
        id: HealthProfileId.value('hp-test'),
        kind: ProfileKind.dependent,
        displayName: 'Test Member',
        bloodType: BloodType.aPositive,
      );
      final f = MemberForm.from(member);
      expect(f.toSave(editing: true, storedBlood: BloodType.oNegative).bloodType, BloodType.oNegative);
      expect(f.toSave(editing: false).bloodType, BloodType.aPositive);
    });

    test('equal drafts are equal, so an unchanged form never notifies', () {
      expect(MemberForm.from(null).withName('A'), MemberForm.from(null).withName('A'));
      expect(MemberForm.from(null).withName('A'), isNot(MemberForm.from(null).withName('B')));
    });
  });

  group('LinkScanDraft', () {
    final found = (
      jti: 'jti-test',
      payload: ProfileQrPayload(lang: 'en', createdAt: DateTime(2030), name: 'Test Person'),
    );

    test('a relation picked before going back to the camera stays; scan another clears it', () {
      final c = container();
      final screen = Object();
      final sub = c.listen(linkScanDraftProvider(screen), (_, __) {});
      final n = c.read(linkScanDraftProvider(screen).notifier)..found(found);
      expect(sub.read().canSend, isFalse);
      n.setRelation(LinkRelation.values.first);
      expect(sub.read().canSend, isTrue);
      n.back();
      expect((sub.read().found, sub.read().relation), (null, LinkRelation.values.first));
      n
        ..found(found)
        ..scanAgain();
      expect(sub.read(), const LinkScanDraft());
    });
  });
}
