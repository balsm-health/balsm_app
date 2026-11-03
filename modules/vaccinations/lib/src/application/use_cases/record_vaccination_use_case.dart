import 'package:core/core.dart';

import '../../domain/aggregates/vaccination_record.dart';
import '../ports/vaccinations_data_source.dart';

/// Records a dose for [profileId] (null = the active profile) from the add
/// form. A [ValidationFailure] lists the broken rules; a profile the
/// signed-in account does not hold, or one that is closed, is a
/// [StorageFailure].
class RecordVaccinationUseCase {
  const RecordVaccinationUseCase(this._vaccinations);

  final VaccinationsDataSource _vaccinations;

  Future<AppResult<VaccinationRecord>> call({
    required String vaccine,
    required int doseNumber,
    required DateTime? administeredOn,
    required DateTime now,
    String? clinic,
    DateTime? nextDueOn,
    HealthProfileId? profileId,
  }) async {
    final made = VaccinationRecord.record(
      vaccine: vaccine,
      doseNumber: doseNumber,
      administeredOn: administeredOn,
      now: now,
      clinic: clinic,
      nextDueOn: nextDueOn,
    );
    if (made.isFailure) return made;
    try {
      await _vaccinations.put(made.value.id, made.value, scope: profileId);
    } on StorageException catch (e) {
      return AppResult.failure(StorageFailure(e.message));
    }
    return made;
  }
}
