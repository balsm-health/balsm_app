import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/aggregates/check_in.dart';
import '../../infrastructure/drift/drift_check_ins_data_source.dart';
import '../ports/check_ins_data_source.dart';

/// Stores the patient's edit of one of their own check-ins, such as a reading
/// removed from the day screen ([CheckIn.without]). A check-in left with
/// nothing in it is deleted; its symptom and pain-region rows cascade.
///
/// When someone other than the patient added, edited or shared the check-in,
/// the edit is appended to its history as the patient's own; the stored
/// history is kept whatever the edited copy carries.
///
/// Any photo lives in the records vault and is removed by the call site
/// through the records module, the same way the flow saved it.
class UpdateCheckInUseCase {
  UpdateCheckInUseCase({required this.dao, DateTime Function() clock = DateTime.now}) : _clock = clock;

  final CheckInsDataSource dao;
  final DateTime Function() _clock;

  /// Returns false when the check-in was empty and so deleted.
  Future<bool> call(CheckIn edited) async {
    if (edited.isEmpty) {
      await dao.delete(edited.id);
      return false;
    }
    final stored = await dao.find(edited.id);
    final history = (stored?.history ?? edited.history).stampSelfEdit(_clock());
    await dao.put(edited.id, edited.withHistory(history));
    return true;
  }
}

final updateCheckInUseCaseProvider = Provider<UpdateCheckInUseCase>(
  (ref) => UpdateCheckInUseCase(dao: ref.watch(checkInsDataSourceProvider)),
);
