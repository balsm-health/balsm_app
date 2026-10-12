import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/aggregates/medication.dart';
import '../../domain/events/medication_added.dart';
import '../ports/medications_data_source.dart';
import '../../infrastructure/drift/drift_medications_data_source.dart';

/// Adds a medication, then rebuilds the OS reminder schedule.
class AddMedicationUseCase {
  AddMedicationUseCase({
    required this.dao,
    required this.bus,
  });

  final MedicationsDataSource dao;
  final EventBus bus;

  Future<void> call(Medication medication) async {
    await dao.put(medication.id, medication);
    bus.publish(MedicationAdded(
      medicationId: medication.id,
      userId: medication.userId,
      name: medication.name,
      occurredAt: DateTime.now(),
    ));
  }
}

// autoDispose for the same reason as [medicationSchedulerProvider]: one
// cached instance per user id, retained for the process lifetime otherwise.
final addMedicationUseCaseProvider = Provider.autoDispose.family<AddMedicationUseCase, UserId>((ref, userId) {
  return AddMedicationUseCase(
    dao: ref.watch(medicationsDataSourceProvider),
    bus: ref.watch(eventBusProvider),
  );
});
