import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infrastructure/drift/medication_dao.dart';
import '../../infrastructure/drift/medication_scheduler.dart';

/// Soft-deletes a medication (sets end date to yesterday) and rebuilds the OS
/// reminder schedule so future triggers stop. Dose history is preserved.
class DeleteMedicationUseCase {
  DeleteMedicationUseCase({required this.dao, required this.scheduler});

  final MedicationDao dao;
  final MedicationScheduler scheduler;

  Future<void> call(UuidV7 medicationId) async {
    await dao.deleteMedication(medicationId);
    await scheduler.rebuildSchedule();
  }
}

final deleteMedicationUseCaseProvider =
    Provider.family<DeleteMedicationUseCase, String>((ref, userId) {
  return DeleteMedicationUseCase(
    dao: ref.watch(medicationDaoProvider),
    scheduler: ref.watch(medicationSchedulerProvider(userId)),
  );
});
