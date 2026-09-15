import 'package:app/balsm_app/app_state.dart';
import 'package:core/core.dart' show FamilyLinkStatus, Gender;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resetForSignOut clears every account-scoped field', () {
    final s = PatientAppState();
    s.addFamilyMember(name: 'Test Member', relation: 'Sibling', linkJti: 'jti-1', status: FamilyLinkStatus.pending);
    s.selectFamilyMember(s.extraFamily.first.id);
    s.setGender(Gender.female);
    s.setAuthContact(method: AuthMethod.email, email: 'old@example.com');
    s.setAuthPassword('transient');

    s.resetForSignOut();

    expect(s.extraFamily, isEmpty);
    expect(s.activeFamilyId, isNull);
    expect(s.linkRequests, isEmpty);
    expect(s.gender, Gender.other);
    expect(s.authEmail, isEmpty);
    expect(s.authPassword, isNull);
  });

  test('device preferences survive the sign-out sweep', () {
    final s = PatientAppState();
    final lang = s.lang;
    final country = s.country;
    final storage = s.storageProvider;

    s.resetForSignOut();

    expect(s.lang, lang);
    expect(s.country, country);
    expect(s.storageProvider, storage);
  });
}
