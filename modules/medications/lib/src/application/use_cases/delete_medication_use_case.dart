import 'package:core/core.dart';

import '../../domain/value_objects/ids.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ports/medications_data_source.dart';
import '../../infrastructure/drift/drift_medications_data_source.dart';

/// Soft-deletes a medication (sets end date to yesterday) and rebuilds the OS
/// reminder schedule so future triggers stop. Dose history is preserved.
class DeleteMedicationUseCase {
  DeleteMedicationUseCase({required this.dao});

  final MedicationsDataSource dao;

  Future<void> call(MedicationId medicationId) async {
    await dao.delete(medicationId);
  }
}

// autoDispose: see [addMedicationUseCaseProvider].
final deleteMedicationUseCaseProvider = Provider.autoDispose.family<DeleteMedicationUseCase, UserId>((ref, userId) {
  return DeleteMedicationUseCase(
    dao: ref.watch(medicationsDataSourceProvider),
  );
});
