import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/aggregates/check_in.dart';
import '../../domain/value_objects/check_in_metric.dart';
import '../../domain/value_objects/symptom.dart';
import '../../infrastructure/drift/drift_check_ins_data_source.dart';
import '../ports/check_ins_data_source.dart';

/// Stores the patient's edit of one reading they logged (`quicklog.jsx`
/// `QuickLogSheet` with `edit`): the same one-metric form, opened on the
/// stored values, saved back over them.
///
/// The reading keeps its check-in's id, so the edit replaces it rather than
/// adding a second entry; the check-in's other readings are left as they
/// were ([CheckIn.withReading]). Any photo lives in the records vault and is
/// stored or removed by the call site through the records module.
class EditCheckInReadingUseCase {
  EditCheckInReadingUseCase({required this.dao});

  final CheckInsDataSource dao;

  /// Returns the check-in as stored.
  Future<CheckIn> call(CheckIn original, CheckInMetric metric, CheckIn edit, {SymptomId? symptom}) async {
    final edited = original.withReading(metric, edit, symptom: symptom);
    await dao.put(edited.id, edited);
    return edited;
  }
}

final editCheckInReadingUseCaseProvider = Provider<EditCheckInReadingUseCase>(
  (ref) => EditCheckInReadingUseCase(dao: ref.watch(checkInsDataSourceProvider)),
);
