import 'package:core/core.dart';
import 'package:riverpod/src/providers/provider.dart';

import '../../domain/aggregates/medication.dart';
import '../../infrastructure/drift/drift_medications_data_source.dart';
import '../ports/medications_data_source.dart';

/// Updates a medication, then rebuilds the OS reminder schedule.
///
/// The stored history is kept whatever the edited copy carries, and when
/// someone other than the patient added, edited or shared the medication,
/// this edit is appended to it as the patient's own.
class EditMedicationUseCase {
  EditMedicationUseCase({required this.dao, DateTime Function() clock = DateTime.now}) : _clock = clock;

  final MedicationsDataSource dao;
  final DateTime Function() _clock;

  Future<void> call(Medication medication) async {
    final stored = await dao.find(medication.id);
    final history = (stored?.history ?? medication.history).stampSelfEdit(_clock());
    await dao.put(medication.id, medication.copyWith(history: history));
  }
}

// autoDispose: see [addMedicationUseCaseProvider].
final ProviderFamily<EditMedicationUseCase, UserId> editMedicationUseCaseProvider =
    Provider.autoDispose.family<EditMedicationUseCase, UserId>((ref, userId) {
  return EditMedicationUseCase(
    dao: ref.watch(medicationsDataSourceProvider),
  );
});
