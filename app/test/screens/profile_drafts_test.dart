import 'package:account/account.dart';
import 'package:app/balsm_app/screens/profile_edit_draft.dart';
import 'package:app/balsm_app/screens/profile_subscreens.dart' show bloodUnsureProvider;
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Personal details and medical-profile drafts without a widget. Every
/// value is synthetic.
void main() {
  group('ProfileEditDraft', () {
    late ProfileDetails stored;
    late ProviderContainer container;
    final form = Object();

    setUp(() {
      stored = const ProfileDetails(
        handle: 'test.handle',
        gender: Gender.female,
        nationality: 'EG',
        dateOfBirth: '2000-01-02',
      );
      container = ProviderContainer(
        retry: noProviderRetry,
        overrides: [profileDetailsProvider.overrideWith((ref) async => stored)],
      );
      addTearDown(container.dispose);
      container.listen(profileEditDraftProvider(form), (_, __) {});
    });

    ProfileEditDraft st() => container.read(profileEditDraftProvider(form));
    ProfileEditDraftNotifier ctrl() => container.read(profileEditDraftProvider(form).notifier);

    test('is not loaded while there is no profile', () async {
      final empty = ProviderContainer(
        retry: noProviderRetry,
        overrides: [profileDetailsProvider.overrideWith((ref) async => null)],
      );
      addTearDown(empty.dispose);
      empty.listen(profileEditDraftProvider(form), (_, __) {});
      await pumpEventQueue();
      expect(empty.read(profileEditDraftProvider(form)), const ProfileEditDraft());
    });

    test('seeds once from the stored profile', () async {
      await pumpEventQueue();
      expect(
        st(),
        ProfileEditDraft(
          loaded: true,
          origHandle: 'test.handle',
          gender: Gender.female,
          nationality: CountryCode.tryFromCode('EG'),
          dob: DateTime(2000, 1, 2),
        ),
      );
      expect(st().isoDob, '2000-01-02');
    });

    test('a re-fetch after a save does not overwrite the edits', () async {
      await pumpEventQueue();
      ctrl().setGender(Gender.male);
      stored = const ProfileDetails(handle: 'other.handle', gender: Gender.female);
      container.invalidate(profileDetailsProvider);
      await pumpEventQueue();
      expect((st().gender, st().origHandle), (Gender.male, 'test.handle'));
    });

    test('unparseable stored values show as unset', () {
      final d = ProfileEditDraft.from(const ProfileDetails(nationality: 'not a code', dateOfBirth: 'someday'));
      expect((d.nationality, d.dob, d.isoDob), (null, null, null));
    });

    test('field transitions, and the relationship clears after a contact is added', () async {
      await pumpEventQueue();
      ctrl()
        ..setDob(DateTime(1999, 12, 31))
        ..setEmRelation(Relationship.values.first)
        ..handleClaimed('new.handle');
      expect((st().isoDob, st().emRelation, st().origHandle), ('1999-12-31', Relationship.values.first, 'new.handle'));
      ctrl().setEmRelation(null);
      expect(st().emRelation, isNull);
    });
  });

  group('bloodUnsureProvider', () {
    test('"Not sure" shows until a type is picked, per screen', () {
      final container = ProviderContainer(retry: noProviderRetry);
      addTearDown(container.dispose);
      final form = Object();
      container.listen(bloodUnsureProvider(form), (_, __) {});
      final ctrl = container.read(bloodUnsureProvider(form).notifier)..picked(null);
      expect(container.read(bloodUnsureProvider(form)), isTrue);
      expect(container.read(bloodUnsureProvider(Object())), isFalse);
      ctrl.picked(BloodType.values.first);
      expect(container.read(bloodUnsureProvider(form)), isFalse);
    });
  });
}
