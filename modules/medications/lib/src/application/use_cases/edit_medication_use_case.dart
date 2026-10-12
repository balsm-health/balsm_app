import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/aggregates/medication.dart';
import '../ports/medications_data_source.dart';
import '../../infrastructure/drift/drift_medications_data_source.dart';

/// Updates a medication, then rebuilds the OS reminder schedule.
class EditMedicationUseCase {
  EditMedicationUseCase({required this.dao});

  final MedicationsDataSource dao;

  Future<void> call(Medication medication) async {
    await dao.put(medication.id, medication);
  }
}

// autoDispose: see [addMedicationUseCaseProvider].
final editMedicationUseCaseProvider = Provider.autoDispose.family<EditMedicationUseCase, UserId>((ref, userId) {
  return EditMedicationUseCase(
    dao: ref.watch(medicationsDataSourceProvider),
  );
});
