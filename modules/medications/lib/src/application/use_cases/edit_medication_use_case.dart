import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/aggregates/medication.dart';
import '../../infrastructure/drift/medications_data_source.dart';
import '../../infrastructure/drift/medication_scheduler.dart';

/// Updates a medication, then rebuilds the OS reminder schedule.
class EditMedicationUseCase {
  EditMedicationUseCase({required this.dao, required this.scheduler});

  final DriftMedicationsDataSource dao;
  final MedicationScheduler scheduler;

  Future<void> call(Medication medication) async {
    await dao.put(medication.id, medication);
    await scheduler.rebuildSchedule();
  }
}

final editMedicationUseCaseProvider =
    Provider.family<EditMedicationUseCase, UserId>((ref, userId) {
  return EditMedicationUseCase(
    dao: ref.watch(medicationsDataSourceProvider),
    scheduler: ref.watch(medicationSchedulerProvider(userId)),
  );
});
