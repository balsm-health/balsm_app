import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/pregnancy_baby.dart';
import '../../domain/value_objects/birth_details.dart';

/// The babies of a pregnancy — prenatal health profiles of the signed-in
/// account, read and written for the pregnancy screens.
///
/// Those profiles are Personal Health roots owned by the profile module
/// (`HealthProfile.createMember` / `born` hold their rules). This module may
/// not import it, so it declares the port and the app composition root binds
/// it to the profile module's data source — the same seam as family's
/// `FamilyMembersPort`. Everything stays on the device.
abstract interface class PregnancyBabiesPort {
  /// Every baby of [pregnancy] — active, born or no longer followed — by
  /// sequence. Emits now and again after each profile change.
  Stream<List<PregnancyBaby>> watchBabies(PregnancyId pregnancy);

  /// One read of [watchBabies].
  Future<List<PregnancyBaby>> listBabies(PregnancyId pregnancy);

  /// Stores a new prenatal profile for [pregnancy] at [sequence]: no name,
  /// no sex, no date of birth.
  Future<AppResult<PregnancyBaby>> addBaby(PregnancyId pregnancy, {required int sequence, required DateTime now});

  /// Gives baby [id] a name, or clears it with a blank one (the default
  /// label shows again). [NotFoundFailure] when it is not an open baby.
  Future<AppResult<void>> renameBaby(HealthProfileId id, String? name, {required DateTime now});

  /// Closes baby [id]'s profile — its records stay, it is no longer shown.
  /// [NotFoundFailure] when it is not open.
  Future<AppResult<void>> closeBaby(HealthProfileId id, {required DateTime now});

  /// Birth: baby [BirthDetails.babyId]'s prenatal profile becomes the child's
  /// (same id). [NotFoundFailure] when it is not an open prenatal profile;
  /// [ValidationFailure] when the profile rules refuse the details.
  Future<AppResult<void>> recordBirth(BirthDetails details, {required DateTime now});
}

/// Bound in the app composition root (`bootstrap()`) to the profile-backed
/// adapter via `overrideWith`.
final pregnancyBabiesPortProvider = Provider<PregnancyBabiesPort>(
  (ref) => throw UnimplementedError('pregnancyBabiesPortProvider must be overridden in bootstrap()'),
);
