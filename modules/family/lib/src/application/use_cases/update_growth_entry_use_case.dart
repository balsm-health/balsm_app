import 'package:core/core.dart';

import '../../domain/aggregates/growth_entry.dart';
import '../../domain/value_objects/growth_entry_id.dart';
import '../ports/growth_log_data_source.dart';

/// Saves the edit form over an existing measurement [id] of [profileId]
/// (null = the active profile), under the same rules as a new one. The entry
/// keeps its id and when it was first recorded. A [ValidationFailure] lists
/// the broken rules; an entry that is gone (or deleted) is a
/// [NotFoundFailure]; a profile the signed-in account does not hold, or one
/// that is closed, is a [StorageFailure].
class UpdateGrowthEntryUseCase {
  const UpdateGrowthEntryUseCase(this._growth);

  final GrowthLogDataSource _growth;

  Future<AppResult<GrowthEntry>> call({
    required GrowthEntryId id,
    required DateTime? measuredOn,
    required double? weightKg,
    required double? heightCm,
    required DateTime now,
    HealthProfileId? profileId,
  }) async {
    final made = GrowthEntry.record(measuredOn: measuredOn, weightKg: weightKg, heightCm: heightCm, now: now, id: id);
    if (made.isFailure) return made;
    try {
      final existing = await _growth.find(id, scope: profileId);
      if (existing == null) return AppResult.failure(const NotFoundFailure('growth entry'));
      final edited = made.value;
      final kept = GrowthEntry(
        id: id,
        measuredOn: edited.measuredOn,
        weightKg: edited.weightKg,
        heightCm: edited.heightCm,
        createdAt: existing.createdAt,
      );
      await _growth.put(id, kept, scope: profileId);
      return AppResult.success(kept);
    } on StorageException catch (e) {
      return AppResult.failure(StorageFailure(e.message));
    }
  }
}
