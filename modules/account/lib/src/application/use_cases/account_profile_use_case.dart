import 'dart:convert';

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

/// Reads and writes the signed-in user's full profile.
///
/// Online it is the account API:
/// GET  /account/self      -> [ProfileDetails]
/// PATCH /account/profile  -> partial update; 422 = under-18 DOB.
///
/// A device-only account has no server profile and may not call the API, so
/// its details are kept on the device in secure storage (encrypted by the
/// platform keystore, like the offline password hash) under [kLocalProfileKey],
/// with the same rules: a null field is unchanged, an empty one clears, and an
/// under-18 date of birth is refused. [publishLocal] hands them to the server
/// once the account goes online.
class AccountProfileUseCase {
  AccountProfileUseCase(this._api, this._storage);

  final AccountApi _api;
  final SecureStorageWrapper _storage;

  /// PHI (date of birth, national ID): never log or export it.
  static const kLocalProfileKey = 'balsm.offline.profile';

  Future<bool> _deviceOnly() async =>
      AccountMode.fromWire(await _storage.readToken(kAccountModeKey)) == AccountMode.deviceOnly;

  Future<ProfileDetails?> _readLocal() async {
    final raw = await _storage.readToken(kLocalProfileKey);
    if (raw == null || raw.isEmpty) return null;
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return ProfileDetails(
      firstName: j['first_name'] as String?,
      lastName: j['last_name'] as String?,
      displayName: _joinName(j['first_name'] as String?, j['last_name'] as String?),
      bio: j['bio'] as String?,
      gender: j['gender'] == null ? null : Gender.fromString(j['gender'] as String),
      nationality: j['nationality'] as String?,
      phone: j['phone'] as String?,
      dateOfBirth: j['date_of_birth'] as String?,
      nationalId: j['national_id'] as String?,
    );
  }

  static String? _joinName(String? first, String? last) {
    final name = [first, last].where((p) => (p ?? '').trim().isNotEmpty).join(' ');
    return name.isEmpty ? null : name;
  }

  /// [next] when given (empty clears to null), else [current].
  static String? _merge(String? current, String? next) => next == null ? current : (next.isEmpty ? null : next);

  /// The server's rule, applied on the device: 18 or older on the given date.
  static bool _isUnder18(String yyyyMmDd, DateTime today) {
    final dob = DateTime.tryParse(yyyyMmDd);
    if (dob == null) return false;
    final eighteenth = DateTime(dob.year + 18, dob.month, dob.day);
    return DateTime(today.year, today.month, today.day).isBefore(eighteenth);
  }

  Future<AppResult<void>> _updateLocal(UpdateProfileInput input) async {
    final cur = await _readLocal() ?? const ProfileDetails();
    final dob = _merge(cur.dateOfBirth, input.dateOfBirth);
    if (dob != null && _isUnder18(dob, DateTime.now())) {
      return AppResult.failure(const ValidationFailure('You must be 18 or older'));
    }
    try {
      await _storage.writeToken(
          kLocalProfileKey,
          jsonEncode({
            'first_name': _merge(cur.firstName, input.firstName),
            'last_name': _merge(cur.lastName, input.lastName),
            'bio': _merge(cur.bio, input.bio),
            'gender': (input.gender ?? cur.gender)?.name,
            'nationality': _merge(cur.nationality, input.nationality),
            'phone': _merge(cur.phone, input.phone),
            'date_of_birth': dob,
            'national_id': _merge(cur.nationalId, input.nationalId),
          }));
      return AppResult.success(null);
    } catch (_) {
      return AppResult.failure(const StorageFailure());
    }
  }

  /// Sends a device-only account's saved details to the server once it is
  /// online as a new account, then forgets the local copy. Kept on failure, so
  /// the next call retries; a no-op when nothing is saved locally.
  Future<AppResult<void>> publishLocal() async {
    final local = await _readLocal();
    if (local == null) return AppResult.success(null);
    final r = await _updateRemote(UpdateProfileInput(
      firstName: local.firstName,
      lastName: local.lastName,
      bio: local.bio,
      gender: local.gender,
      nationality: local.nationality,
      phone: local.phone,
      dateOfBirth: local.dateOfBirth,
      nationalId: local.nationalId,
    ));
    if (r.isSuccess) await dropLocal();
    return r;
  }

  /// The details a device-only account saved on the device, or null when
  /// there are none yet.
  Future<ProfileDetails?> localDetails() => _readLocal();

  /// Forgets the device-only details without sending them — after merging
  /// into an account that already has its own profile on the server.
  Future<void> dropLocal() => _storage.deleteToken(kLocalProfileKey);

  Future<ProfileDetails?> load() async {
    // Never null for a device-only account: the details screen waits for a
    // profile before it allows a save, and a new account has none yet.
    if (await _deviceOnly()) return await _readLocal() ?? const ProfileDetails();
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
    if (await _deviceOnly()) return _updateLocal(input);
    return _updateRemote(input);
  }

  Future<AppResult<void>> _updateRemote(UpdateProfileInput input) async {
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
      // Ahead of the switch: an offline failure carries a null statusCode, and
      // so does an unmapped one — the switch cannot tell them apart.
      if (e.isOffline) return AppResult.failure(const OfflineFailure());
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
  return AccountProfileUseCase(ref.watch(accountApiProvider), ref.watch(secureStorageProvider));
});
