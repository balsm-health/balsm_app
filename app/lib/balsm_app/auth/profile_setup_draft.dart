import 'package:core/core.dart' show Gender;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;

/// What the profile-setup form holds besides its text fields (names and
/// handle stay in their controllers; the handle's check is
/// `handleCheckProvider`). The date of birth is personal data, so the
/// provider is auto-disposed: the draft goes with the form.
@immutable
class ProfileSetupDraft {
  const ProfileSetupDraft({this.dob, this.gender = Gender.female});
  final DateTime? dob;
  final Gender gender;

  ProfileSetupDraft withDob(DateTime dob) => ProfileSetupDraft(dob: dob, gender: gender);
  ProfileSetupDraft withGender(Gender gender) => ProfileSetupDraft(dob: dob, gender: gender);

  @override
  bool operator ==(Object other) => other is ProfileSetupDraft && other.dob == dob && other.gender == gender;

  @override
  int get hashCode => Object.hash(dob, gender);
}

/// One draft per form: the key is a token the form's State creates once.
class ProfileSetupDraftNotifier extends Notifier<ProfileSetupDraft> {
  ProfileSetupDraftNotifier(this.form);
  final Object form;

  @override
  ProfileSetupDraft build() => const ProfileSetupDraft();

  void setDob(DateTime dob) => state = state.withDob(dob);
  void setGender(Gender gender) => state = state.withGender(gender);
}

final NotifierProviderFamily<ProfileSetupDraftNotifier, ProfileSetupDraft, Object> profileSetupDraftProvider =
    NotifierProvider.autoDispose.family<ProfileSetupDraftNotifier, ProfileSetupDraft, Object>(
  ProfileSetupDraftNotifier.new,
);
