import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show StreamProviderFamily;

import '../application/use_cases/delete_growth_entry_use_case.dart';
import '../application/use_cases/record_growth_entry_use_case.dart';
import '../application/use_cases/update_growth_entry_use_case.dart';
import '../domain/aggregates/growth_entry.dart';
import '../infrastructure/drift/drift_growth_log_data_source.dart';

/// Person `profileId`'s growth log, newest measurement first, live. Empty
/// while signed out.
final StreamProviderFamily<List<GrowthEntry>, HealthProfileId> growthEntriesProvider =
    StreamProvider.autoDispose.family<List<GrowthEntry>, HealthProfileId>((ref, profileId) {
  if (ref.watch(currentUserIdProvider) == null) return Stream.value(const []);
  return ref.watch(growthLogDataSourceProvider).watchAll(scope: profileId);
});

final recordGrowthEntryUseCaseProvider = Provider<RecordGrowthEntryUseCase>(
  (ref) => RecordGrowthEntryUseCase(ref.watch(growthLogDataSourceProvider)),
);

final updateGrowthEntryUseCaseProvider = Provider<UpdateGrowthEntryUseCase>(
  (ref) => UpdateGrowthEntryUseCase(ref.watch(growthLogDataSourceProvider)),
);

final deleteGrowthEntryUseCaseProvider = Provider<DeleteGrowthEntryUseCase>(
  (ref) => DeleteGrowthEntryUseCase(ref.watch(growthLogDataSourceProvider)),
);
