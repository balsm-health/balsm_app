import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/aggregates/medication.dart';
import '../../infrastructure/drift/medication_dao.dart';
import '../../infrastructure/drift/medication_scheduler.dart';

/// Updates a medication, then rebuilds the OS reminder schedule.
class EditMedicationUseCase {
  EditMedicationUseCase({required this.dao, required this.scheduler});

  final MedicationDao dao;
  final MedicationScheduler scheduler;

  Future<void> call(Medication medication) async {
    await dao.updateMedication(medication);
    await scheduler.rebuildSchedule();
  }
}

final editMedicationUseCaseProvider =
    Provider.family<EditMedicationUseCase, String>((ref, userId) {
  return EditMedicationUseCase(
    dao: ref.watch(medicationDaoProvider),
    scheduler: ref.watch(medicationSchedulerProvider(userId)),
  );
});
