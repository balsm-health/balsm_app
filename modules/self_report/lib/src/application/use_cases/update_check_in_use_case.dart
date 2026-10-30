import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/aggregates/check_in.dart';
import '../ports/check_ins_data_source.dart';
import '../../infrastructure/drift/drift_check_ins_data_source.dart';

/// Stores the patient's edit of one of their own check-ins, such as a reading
/// removed from the day screen ([CheckIn.without]). A check-in left with
/// nothing in it is deleted; its symptom and pain-region rows cascade.
///
/// Any photo lives in the records vault and is removed by the call site
/// through the records module, the same way the flow saved it.
class UpdateCheckInUseCase {
  UpdateCheckInUseCase({required this.dao});

  final CheckInsDataSource dao;

  /// Returns false when the check-in was empty and so deleted.
  Future<bool> call(CheckIn edited) async {
    if (edited.isEmpty) {
      await dao.delete(edited.id);
      return false;
    }
    await dao.put(edited.id, edited);
    return true;
  }
}

final updateCheckInUseCaseProvider = Provider<UpdateCheckInUseCase>(
  (ref) => UpdateCheckInUseCase(dao: ref.watch(checkInsDataSourceProvider)),
);
