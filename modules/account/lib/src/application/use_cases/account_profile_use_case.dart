import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Full self-profile read model. PHI-carrying ([dateOfBirth], [nationalId]) —
/// scoped to the account-details screen; deliberately NOT merged into the
/// app-wide [AccountSummary], which stays PHI-free. Never log or persist this.
class ProfileDetails {
  const ProfileDetails({
    this.handle,
    this.displayName,
    this.bio,
    this.gender,
    this.nationality,
    this.phone,
    this.dateOfBirth,
    this.nationalId,
  });

  final String? handle;
  final String? displayName;
  final String? bio;
  final String? gender;
  final String? nationality;
  final String? phone;
  final String? dateOfBirth; // yyyy-MM-dd
  final String? nationalId;
}

/// Partial-update input: a null field is left unchanged server-side; an empty
/// string clears it.
class UpdateProfileInput {
  const UpdateProfileInput({
    this.displayName,
    this.bio,
    this.gender,
    this.nationality,
    this.phone,
    this.dateOfBirth,
    this.nationalId,
  });

  final String? displayName;
  final String? bio;
  final String? gender;
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
      displayName: res.displayName,
      bio: res.bio,
      gender: res.gender,
      nationality: res.nationality,
      phone: res.phone,
      dateOfBirth: res.dateOfBirth,
      nationalId: res.nationalId,
    );
  }

  Future<AppResult<void>> update(UpdateProfileInput input) async {
    try {
      await _api.updateProfile(UpdateProfileRequest(
        displayName: input.displayName,
        bio: input.bio,
        gender: input.gender,
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
