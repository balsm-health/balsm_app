import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/src/providers/stream_provider.dart';

import '../application/use_cases/delete_vaccination_use_case.dart';
import '../application/use_cases/record_vaccination_use_case.dart';
import '../application/use_cases/update_vaccination_use_case.dart';
import '../domain/aggregates/vaccination_record.dart';
import '../infrastructure/drift/drift_vaccinations_data_source.dart';

/// Person `profileId`'s vaccination log, newest dose first, live. Empty while
/// signed out.
final StreamProviderFamily<List<VaccinationRecord>, HealthProfileId> vaccinationsProvider =
    StreamProvider.autoDispose.family<List<VaccinationRecord>, HealthProfileId>((ref, profileId) {
  if (ref.watch(currentUserIdProvider) == null) return Stream.value(const []);
  return ref.watch(vaccinationsDataSourceProvider).watchAll(scope: profileId);
});

final recordVaccinationUseCaseProvider = Provider<RecordVaccinationUseCase>(
  (ref) => RecordVaccinationUseCase(ref.watch(vaccinationsDataSourceProvider)),
);

final updateVaccinationUseCaseProvider = Provider<UpdateVaccinationUseCase>(
  (ref) => UpdateVaccinationUseCase(ref.watch(vaccinationsDataSourceProvider)),
);

final deleteVaccinationUseCaseProvider = Provider<DeleteVaccinationUseCase>(
  (ref) => DeleteVaccinationUseCase(ref.watch(vaccinationsDataSourceProvider)),
);
