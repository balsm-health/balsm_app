import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/ports/pregnancies_data_source.dart';
import '../application/ports/pregnancy_babies_port.dart';
import '../application/use_cases/end_pregnancy_use_case.dart';
import '../application/use_cases/pregnancy_babies_use_case.dart';
import '../application/use_cases/pregnancy_records_use_case.dart';
import '../application/use_cases/record_birth_use_case.dart';
import '../application/use_cases/start_pregnancy_use_case.dart';
import '../domain/aggregates/pregnancy.dart';
import '../domain/entities/pregnancy_baby.dart';
import '../domain/entities/pregnancy_item.dart';
import '../infrastructure/drift/drift_pregnancies_data_source.dart';

/// Pregnancies live on the account holder's own (self) profile, whichever
/// profile is active — so the data source is bound to the self profile.
final pregnanciesDataSourceProvider = Provider<PregnanciesDataSource>((ref) {
  return DriftPregnanciesDataSource(
    db: ref.watch(appDatabaseProvider),
    activeProfile: () => ref.read(selfProfileIdProvider).valueOrNull,
  );
});

/// Every pregnancy on the self profile (active and closed), newest first,
/// live. Empty while signed out.
final pregnanciesProvider = StreamProvider<List<Pregnancy>>((ref) async* {
  final self = await ref.watch(selfProfileIdProvider.future);
  if (self == null) {
    yield const [];
    return;
  }
  yield* ref.watch(pregnanciesDataSourceProvider).watchAll(scope: self);
});

/// The pregnancy being tracked, or null. Null while loading too — check
/// [pregnanciesProvider] to tell the two apart.
final activePregnancyProvider = Provider<Pregnancy?>(
  (ref) => ref.watch(pregnanciesProvider).valueOrNull?.where((p) => p.isActive).firstOrNull,
);

/// The babies of pregnancy [id] — active, born and no longer followed —
/// live.
final pregnancyBabiesProvider = StreamProvider.family<List<PregnancyBaby>, PregnancyId>(
  (ref, id) => ref.watch(pregnancyBabiesPortProvider).watchBabies(id),
);

/// The items of pregnancy [id], newest first, live.
final pregnancyItemsProvider = StreamProvider.family<List<PregnancyItem>, PregnancyId>((ref, id) async* {
  final self = await ref.watch(selfProfileIdProvider.future);
  if (self == null) {
    yield const [];
    return;
  }
  yield* ref.watch(pregnanciesDataSourceProvider).watchItems(id, scope: self);
});

/// Whether the account holder dismissed the home "start pregnancy" prompt
/// ("Not now"), kept per account on this device. Not PHI: it records a tap,
/// not a pregnancy.
class PregnancyPromptDismissal extends AsyncNotifier<bool> {
  static String _key(UserId user) => 'pregnancy.prompt_dismissed.${user.value}';

  @override
  Future<bool> build() async {
    final user = ref.watch(currentUserIdProvider);
    if (user == null) return false;
    return await ref.watch(globalKVDataSourceProvider).get<bool>(_key(user)) ?? false;
  }

  Future<void> dismiss() async {
    final user = ref.read(currentUserIdProvider);
    if (user == null) return;
    await ref.read(globalKVDataSourceProvider).put<bool>(_key(user), true);
    state = const AsyncData(true);
  }
}

final pregnancyPromptDismissedProvider =
    AsyncNotifierProvider<PregnancyPromptDismissal, bool>(PregnancyPromptDismissal.new);

final startPregnancyUseCaseProvider = Provider<StartPregnancyUseCase>(
  (ref) => StartPregnancyUseCase(
    pregnancies: ref.watch(pregnanciesDataSourceProvider),
    babies: ref.watch(pregnancyBabiesPortProvider),
  ),
);

final pregnancyBabiesUseCaseProvider = Provider<PregnancyBabiesUseCase>(
  (ref) => PregnancyBabiesUseCase(
    pregnancies: ref.watch(pregnanciesDataSourceProvider),
    babies: ref.watch(pregnancyBabiesPortProvider),
  ),
);

final endPregnancyUseCaseProvider = Provider<EndPregnancyUseCase>(
  (ref) => EndPregnancyUseCase(
    pregnancies: ref.watch(pregnanciesDataSourceProvider),
    babies: ref.watch(pregnancyBabiesPortProvider),
  ),
);

final recordBirthUseCaseProvider = Provider<RecordBirthUseCase>(
  (ref) => RecordBirthUseCase(
    pregnancies: ref.watch(pregnanciesDataSourceProvider),
    babies: ref.watch(pregnancyBabiesPortProvider),
  ),
);

final pregnancyRecordsUseCaseProvider = Provider<PregnancyRecordsUseCase>(
  (ref) => PregnancyRecordsUseCase(
    pregnancies: ref.watch(pregnanciesDataSourceProvider),
    babies: ref.watch(pregnancyBabiesPortProvider),
  ),
);
