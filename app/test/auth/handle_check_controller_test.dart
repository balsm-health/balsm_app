import 'package:app/balsm_app/app_state.dart' show UsernameStatus;
import 'package:app/balsm_app/auth/handle_check_controller.dart';
import 'package:app/balsm_app/auth/profile_setup_draft.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The handle check shared by profile setup and Personal details, without a
/// widget. [FakeAccountApi] reports `balsm` and `admin` as taken.
void main() {
  group('HandleCheck.typed', () {
    test('normalizes to the characters a handle can hold', () {
      expect(HandleCheck.normalize('Test.User_1!'), 'test.user_1');
    });

    test('empty is "required" only where a handle is mandatory', () {
      expect(HandleCheck.typed('', required: true).status, UsernameStatus.required);
      expect(HandleCheck.typed('', required: false).status, UsernameStatus.idle);
    });

    test("the account's own handle is no change; a bad format is invalid; anything else is checked", () {
      expect(HandleCheck.typed('mine', required: true, original: 'mine').status, UsernameStatus.idle);
      expect(HandleCheck.typed('ab', required: true).status, UsernameStatus.invalid);
      expect(HandleCheck.typed('a' * 31, required: true).status, UsernameStatus.invalid);
      expect(HandleCheck.typed('test.handle', required: true).status, UsernameStatus.checking);
    });

    test('only idle and available let a form save', () {
      expect(const HandleCheck().acceptable, isTrue);
      expect(const HandleCheck(status: UsernameStatus.available).acceptable, isTrue);
      expect(const HandleCheck(status: UsernameStatus.checking).acceptable, isFalse);
      expect(const HandleCheck(status: UsernameStatus.taken).acceptable, isFalse);
    });
  });

  group('HandleCheckController', () {
    late ProviderContainer container;
    final key = (form: Object(), required: true);

    setUp(() {
      container = ProviderContainer(
        retry: noProviderRetry,
        overrides: [accountApiProvider.overrideWithValue(FakeAccountApi())],
      );
      addTearDown(container.dispose);
      container.listen(handleCheckProvider(key), (_, __) {});
    });

    HandleCheckController ctrl() => container.read(handleCheckProvider(key).notifier);
    HandleCheck st() => container.read(handleCheckProvider(key));
    Future<void> afterDebounce() => Future<void>.delayed(HandleCheckController.debounce * 2);

    test('asks the server after the pause and shows its answer', () async {
      expect(ctrl().changed('Free_Handle'), 'free_handle');
      expect(st().status, UsernameStatus.checking);
      await afterDebounce();
      expect(st(), const HandleCheck(handle: 'free_handle', status: UsernameStatus.available));

      ctrl().changed('balsm');
      await afterDebounce();
      expect(st().status, UsernameStatus.taken);
    });

    test('typing on before the pause ends drops the stale check', () async {
      ctrl()
        ..changed('balsm')
        ..changed('free_handle');
      await afterDebounce();
      expect(st(), const HandleCheck(handle: 'free_handle', status: UsernameStatus.available));
    });

    test('settle shows a claimed handle as unchanged; markTaken and markRequired set their status', () async {
      ctrl().changed('free_handle');
      ctrl().settle('free_handle');
      await afterDebounce();
      expect(st(), const HandleCheck(handle: 'free_handle'));
      ctrl().markTaken();
      expect(st().status, UsernameStatus.taken);
      ctrl().markRequired();
      expect(st().status, UsernameStatus.required);
    });
  });

  group('ProfileSetupDraft', () {
    test('holds the date of birth and gender, compared by value', () {
      final container = ProviderContainer(retry: noProviderRetry);
      addTearDown(container.dispose);
      final form = Object();
      container.listen(profileSetupDraftProvider(form), (_, __) {});
      container.read(profileSetupDraftProvider(form).notifier)
        ..setDob(DateTime(2000))
        ..setGender(Gender.male);
      expect(
        container.read(profileSetupDraftProvider(form)),
        ProfileSetupDraft(dob: DateTime(2000), gender: Gender.male),
      );
      expect(container.read(profileSetupDraftProvider(Object())), const ProfileSetupDraft(), reason: 'per form');
    });
  });
}
