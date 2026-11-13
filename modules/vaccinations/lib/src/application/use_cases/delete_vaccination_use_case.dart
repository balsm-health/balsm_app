import 'package:core/core.dart';

import '../../domain/value_objects/ids.dart';
import '../ports/vaccinations_data_source.dart';

/// Removes dose [id] from [profileId]'s log (null = the active profile). The
/// delete is soft: the row stays on the device, stamped, and reads leave it
/// out. A profile the signed-in account does not hold, or one that is
/// closed, is a [StorageFailure].
class DeleteVaccinationUseCase {
  const DeleteVaccinationUseCase(this._vaccinations);

  final VaccinationsDataSource _vaccinations;

  Future<AppResult<void>> call(VaccinationRecordId id, {HealthProfileId? profileId}) async {
    try {
      await _vaccinations.delete(id, scope: profileId);
    } on StorageException catch (e) {
      return AppResult.failure(StorageFailure(e.message));
    }
    return AppResult.success(null);
  }
}
