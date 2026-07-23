import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/aggregates/medication.dart';
import '../../domain/events/medication_added.dart';
import '../../infrastructure/drift/medications_data_source.dart';
import '../../infrastructure/drift/medication_scheduler.dart';

/// Adds a medication, then rebuilds the OS reminder schedule.
class AddMedicationUseCase {
  AddMedicationUseCase({
    required this.dao,
    required this.bus,
    required this.scheduler,
  });

  final DriftMedicationsDataSource dao;
  final EventBus bus;
  final MedicationScheduler scheduler;

  Future<void> call(Medication medication) async {
    await dao.put(medication.id, medication);
    bus.publish(MedicationAdded(
      medicationId: medication.id,
      userId: medication.userId,
      name: medication.name,
      occurredAt: DateTime.now(),
    ));
    await scheduler.rebuildSchedule();
  }
}

final addMedicationUseCaseProvider =
    Provider.family<AddMedicationUseCase, UserId>((ref, userId) {
  return AddMedicationUseCase(
    dao: ref.watch(medicationsDataSourceProvider),
    bus: ref.watch(eventBusProvider),
    scheduler: ref.watch(medicationSchedulerProvider(userId)),
  );
});
