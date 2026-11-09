import 'package:account/account.dart';
import 'package:app/balsm_app/account_gender.dart';
import 'package:app/balsm_app/app_state.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

/// The app's idea of the user's gender comes from their account, at sign-in.
///
/// It used to be copied in only when Personal details was opened, so until
/// then it was [Gender.other]: Arabic copy addressed a woman in the masculine,
/// the body map showed the male figure, and Mother & Child's pregnancy prompt
/// followed whichever value was current, not the account's.
void main() {
  test('takes the gender the account has', () async {
    final state = PatientAppState();
    expect(state.gender, Gender.other, reason: 'the launch default this replaces');

    await syncAccountGender(state, _load(Gender.female));

    expect(state.gender, Gender.female);
  });

  test('replaces an earlier value, so a stale one cannot stick', () async {
    final state = PatientAppState()..setGender(Gender.male);

    await syncAccountGender(state, _load(Gender.female));

    expect(state.gender, Gender.female);
  });

  test('an account with no gender recorded goes back to the neutral default', () async {
    final state = PatientAppState()..setGender(Gender.female);

    await syncAccountGender(state, _load(null));

    expect(state.gender, Gender.other);
  });

  test('an unreadable profile leaves the current value alone', () async {
    // Offline at launch must not reset a known gender to the default. A use
    // case that cannot even be built throws the same way, inside the call.
    final state = PatientAppState()..setGender(Gender.female);

    await syncAccountGender(state, () async => throw Exception('offline'));
    expect(state.gender, Gender.female);

    await syncAccountGender(state, () async => null);
    expect(state.gender, Gender.female);
  });
}

/// A profile load that answers with [gender].
Future<ProfileDetails?> Function() _load(Gender? gender) => () async => ProfileDetails(gender: gender);
