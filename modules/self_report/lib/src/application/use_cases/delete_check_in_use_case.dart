import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/value_objects/ids.dart';
import '../ports/check_ins_data_source.dart';
import '../../infrastructure/drift/drift_check_ins_data_source.dart';

/// Removes one of the active profile's check-ins: the patient's own journal
/// entry, so theirs to erase. Symptom and pain-region rows cascade with it.
///
/// Any photo lives in the records vault and is removed by the call site
/// through the records module, the same way the flow saved it.
class DeleteCheckInUseCase {
  DeleteCheckInUseCase({required this.dao});

  final CheckInsDataSource dao;

  Future<void> call(CheckInId id) => dao.delete(id);
}

final deleteCheckInUseCaseProvider = Provider<DeleteCheckInUseCase>(
  (ref) => DeleteCheckInUseCase(dao: ref.watch(checkInsDataSourceProvider)),
);
