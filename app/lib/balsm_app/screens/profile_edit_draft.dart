import 'package:account/account.dart';
import 'package:core/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;

/// The signed-in user's full editable profile (PHI-carrying: DOB, national ID).
/// Screen-local — the PHI never enters the app-wide AccountSummary. Re-fetched
/// after a save so the head + fields reflect the server.
final FutureProvider<ProfileDetails?> profileDetailsProvider = FutureProvider.autoDispose<ProfileDetails?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return ref.watch(accountProfileUseCaseProvider).load();
});

/// What Personal details holds besides its text fields (names, phone,
/// national ID, handle and the new contact's name and phone stay in their
/// controllers). Personal data, so the provider is auto-disposed: the draft
/// goes with the screen.
@immutable
class ProfileEditDraft {
  const ProfileEditDraft({
    this.loaded = false,
    this.origHandle = '',
    this.gender,
    this.nationality,
    this.dob,
    this.emRelation,
  });

  /// Seeded from the stored profile. Legacy free-text nationalities and dates
  /// that do not parse show the placeholder until re-picked.
  factory ProfileEditDraft.from(ProfileDetails p) => ProfileEditDraft(
        loaded: true,
        origHandle: p.handle ?? '',
        gender: p.gender,
        nationality: switch (p.nationality) {
          final code? when code.isNotEmpty => CountryCode.tryFromCode(code),
          _ => null,
        },
        dob: switch (p.dateOfBirth) {
          final iso? when iso.isNotEmpty => DateTime.tryParse(iso),
          _ => null,
        },
      );

  /// The profile has loaded. Saving before that would send empty fields and
  /// clear the patient's data on the server.
  final bool loaded;

  /// The handle the account holds now; keeping it is no change.
  final String origHandle;
  final Gender? gender;
  final CountryCode? nationality;
  final DateTime? dob;

  /// The new emergency contact's relationship.
  final Relationship? emRelation;

  ProfileEditDraft copyWith({
    String? origHandle,
    Gender? gender,
    CountryCode? nationality,
    DateTime? dob,
    Object? emRelation = _unset,
  }) =>
      ProfileEditDraft(
        loaded: loaded,
        origHandle: origHandle ?? this.origHandle,
        gender: gender ?? this.gender,
        nationality: nationality ?? this.nationality,
        dob: dob ?? this.dob,
        emRelation: identical(emRelation, _unset) ? this.emRelation : emRelation as Relationship?,
      );

  /// `yyyy-MM-dd`, the wire format; null when no date is set.
  String? get isoDob => switch (dob) {
        final d? => '${d.year.toString().padLeft(4, '0')}-'
            '${d.month.toString().padLeft(2, '0')}-'
            '${d.day.toString().padLeft(2, '0')}',
        null => null,
      };

  @override
  bool operator ==(Object other) =>
      other is ProfileEditDraft &&
      other.loaded == loaded &&
      other.origHandle == origHandle &&
      other.gender == gender &&
      other.nationality == nationality &&
      other.dob == dob &&
      other.emRelation == emRelation;

  @override
  int get hashCode => Object.hash(loaded, origHandle, gender, nationality, dob, emRelation);
}

const Object _unset = Object();

/// One draft per open screen (the key is a token its State creates once).
/// Seeds itself once from [profileDetailsProvider]; the re-fetch after a
/// save does not overwrite what the patient is editing.
class ProfileEditDraftNotifier extends Notifier<ProfileEditDraft> {
  ProfileEditDraftNotifier(this.form);
  final Object form;

  @override
  ProfileEditDraft build() {
    ref.listen<AsyncValue<ProfileDetails?>>(profileDetailsProvider, (_, next) {
      final profile = next.value;
      if (profile != null && !state.loaded) state = ProfileEditDraft.from(profile);
    });
    final profile = ref.read(profileDetailsProvider).value;
    return profile == null ? const ProfileEditDraft() : ProfileEditDraft.from(profile);
  }

  void setGender(Gender gender) => state = state.copyWith(gender: gender);
  void setNationality(CountryCode nationality) => state = state.copyWith(nationality: nationality);
  void setDob(DateTime dob) => state = state.copyWith(dob: dob);
  void setEmRelation(Relationship? relation) => state = state.copyWith(emRelation: relation);

  /// [handle] is now the account's own (claimed, or kept on the device).
  void handleClaimed(String handle) => state = state.copyWith(origHandle: handle);
}

final NotifierProviderFamily<ProfileEditDraftNotifier, ProfileEditDraft, Object> profileEditDraftProvider =
    NotifierProvider.autoDispose.family<ProfileEditDraftNotifier, ProfileEditDraft, Object>(
  ProfileEditDraftNotifier.new,
);
