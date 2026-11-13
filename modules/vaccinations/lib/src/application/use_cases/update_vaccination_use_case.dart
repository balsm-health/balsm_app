import 'package:core/core.dart';

import '../../domain/aggregates/vaccination_record.dart';
import '../../domain/value_objects/ids.dart';
import '../ports/vaccinations_data_source.dart';

/// Saves the edit form over an existing dose [id] of [profileId] (null = the
/// active profile), under the same rules as a new one. The dose keeps its id
/// and when it was first recorded. A [ValidationFailure] lists the broken
/// rules; a dose that is gone (or deleted) is a [NotFoundFailure]; a profile
/// the signed-in account does not hold, or one that is closed, is a
/// [StorageFailure].
class UpdateVaccinationUseCase {
  const UpdateVaccinationUseCase(this._vaccinations);

  final VaccinationsDataSource _vaccinations;

  Future<AppResult<VaccinationRecord>> call({
    required VaccinationRecordId id,
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
      id: id,
    );
    if (made.isFailure) return made;
    try {
      final existing = await _vaccinations.find(id, scope: profileId);
      if (existing == null) return AppResult.failure(const NotFoundFailure('vaccination record'));
      final edited = made.value;
      final kept = VaccinationRecord(
        id: id,
        vaccine: edited.vaccine,
        doseNumber: edited.doseNumber,
        administeredOn: edited.administeredOn,
        clinic: edited.clinic,
        nextDueOn: edited.nextDueOn,
        createdAt: existing.createdAt,
      );
      await _vaccinations.put(id, kept, scope: profileId);
      return AppResult.success(kept);
    } on StorageException catch (e) {
      return AppResult.failure(StorageFailure(e.message));
    }
  }
}
