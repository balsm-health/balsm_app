import 'package:core/core.dart';

import '../../domain/aggregates/growth_entry.dart';
import '../ports/growth_log_data_source.dart';

/// Adds a measurement for [profileId] (null = the active profile) from the
/// growth form. A [ValidationFailure] lists the broken rules; a profile the
/// signed-in account does not hold, or one that is closed, is a
/// [StorageFailure].
class RecordGrowthEntryUseCase {
  const RecordGrowthEntryUseCase(this._growth);

  final GrowthLogDataSource _growth;

  Future<AppResult<GrowthEntry>> call({
    required DateTime? measuredOn,
    required double? weightKg,
    required double? heightCm,
    required DateTime now,
    HealthProfileId? profileId,
  }) async {
    final made = GrowthEntry.record(measuredOn: measuredOn, weightKg: weightKg, heightCm: heightCm, now: now);
    if (made.isFailure) return made;
    try {
      await _growth.put(made.value.id, made.value, scope: profileId);
    } on StorageException catch (e) {
      return AppResult.failure(StorageFailure(e.message));
    }
    return made;
  }
}
