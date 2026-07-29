import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Full self-profile read model. PHI-carrying ([dateOfBirth], [nationalId]) —
/// scoped to the account-details screen; deliberately NOT merged into the
/// app-wide [AccountSummary], which stays PHI-free. Never log or persist this.
class ProfileDetails {
  const ProfileDetails({
    this.handle,
    this.firstName,
    this.lastName,
    this.displayName,
    this.bio,
    this.gender,
    this.nationality,
    this.phone,
    this.dateOfBirth,
    this.nationalId,
  });

  final String? handle;

  /// Split name parts. [displayName] is server-derived (`"first last"`) and kept
  /// for the PHI-free app-wide summary / read-only surfaces.
  final String? firstName;
  final String? lastName;
  final String? displayName;
  final String? bio;
  final Gender? gender;
  final String? nationality;
  final String? phone;
  final String? dateOfBirth; // yyyy-MM-dd
  final String? nationalId;
}

/// Partial-update input: a null field is left unchanged server-side; an empty
/// string clears it.
class UpdateProfileInput {
  const UpdateProfileInput({
    this.firstName,
    this.lastName,
    this.bio,
    this.gender,
    this.nationality,
    this.phone,
    this.dateOfBirth,
    this.nationalId,
  });

  // Server derives display_name from first + last; never sent by the client.
  final String? firstName;
  final String? lastName;
  final String? bio;
  final Gender? gender;
  final String? nationality;
  final String? phone;
  final String? dateOfBirth;
  final String? nationalId;
}

/// Reads and writes the signed-in user's full profile via the account API.
///
/// GET  /account/self      -> [ProfileDetails]
/// PATCH /account/profile  -> partial update; 422 = under-18 DOB.
class AccountProfileUseCase {
  AccountProfileUseCase(this._api);

  final AccountApi _api;

  Future<ProfileDetails?> load() async {
    final res = await _api.getSelf();
    if (res == null) return null;
    return ProfileDetails(
      handle: res.handle,
      firstName: res.firstName,
      lastName: res.lastName,
      displayName: res.displayName,
      bio: res.bio,
      // Wire format stays a snake_case string; the model carries the enum.
      gender: res.gender == null ? null : Gender.fromString(res.gender),
      nationality: res.nationality,
      phone: res.phone,
      dateOfBirth: res.dateOfBirth,
      nationalId: res.nationalId,
    );
  }

  Future<AppResult<void>> update(UpdateProfileInput input) async {
    try {
      await _api.updateProfile(UpdateProfileRequest(
        firstName: input.firstName,
        lastName: input.lastName,
        bio: input.bio,
        gender: input.gender?.name,
        nationality: input.nationality,
        phone: input.phone,
        dateOfBirth: input.dateOfBirth,
        nationalId: input.nationalId,
      ));
      return AppResult.success(null);
    } on ApiException catch (e) {
      return AppResult.failure(switch (e.statusCode) {
        401 || 403 => const UnauthorizedFailure(),
        422 => const ValidationFailure('You must be 18 or older'),
        400 => const ValidationFailure('Invalid profile data'),
        _ => const NetworkFailure(),
      });
    }
  }
}

final accountProfileUseCaseProvider = Provider<AccountProfileUseCase>((ref) {
  return AccountProfileUseCase(ref.watch(accountApiProvider));
});
