import 'package:core/core.dart';

import '../../domain/value_objects/growth_entry_id.dart';
import '../ports/growth_log_data_source.dart';

/// Removes measurement `id` from `profileId`'s growth log (null = the active profile). The
/// delete is soft: the row stays on the device, stamped, and reads leave it
/// out. A profile the signed-in account does not hold, or one that is
/// closed, is a [StorageFailure].
class DeleteGrowthEntryUseCase {
  const DeleteGrowthEntryUseCase(this._growth);

  final GrowthLogDataSource _growth;

  Future<AppResult<void>> call(GrowthEntryId id, {HealthProfileId? profileId}) async {
    try {
      await _growth.delete(id, scope: profileId);
    } on StorageException catch (e) {
      return AppResult.failure(StorageFailure(e.message));
    }
    return AppResult.success(null);
  }
}
