import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/src/providers/provider.dart';
import 'package:riverpod/src/providers/stream_provider.dart';

import '../application/ports/pregnancy_babies_port.dart';
import '../application/ports/pregnancy_guidance_source.dart';
import '../application/use_cases/end_pregnancy_use_case.dart';
import '../application/use_cases/pregnancy_babies_use_case.dart';
import '../application/use_cases/pregnancy_records_use_case.dart';
import '../application/use_cases/record_birth_use_case.dart';
import '../application/use_cases/start_pregnancy_use_case.dart';
import '../application/use_cases/watch_pregnancy_guidance_use_case.dart';
import '../domain/aggregates/pregnancy.dart';
import '../domain/entities/pregnancy_baby.dart';
import '../domain/entities/pregnancy_item.dart';
import '../domain/value_objects/weekly_guidance.dart';
import '../infrastructure/drift/drift_pregnancies_data_source.dart';

/// Every pregnancy of mother `motherId` (active and closed), newest first,
/// live. Null is the account holder's own (self) profile; otherwise a
/// family member whose profile the account holder manages — her pregnancy
/// is stored on her own profile (mother-child.jsx `MCPregWho`). Empty while
/// signed out.
final StreamProviderFamily<List<Pregnancy>, HealthProfileId?> pregnanciesOfProvider =
    StreamProvider.family<List<Pregnancy>, HealthProfileId?>((ref, motherId) async* {
  final mother = motherId ?? await ref.watch(selfProfileIdProvider.future);
  if (mother == null || ref.watch(currentUserIdProvider) == null) {
    yield const [];
    return;
  }
  yield* ref.watch(pregnanciesDataSourceProvider).watchAll(scope: mother);
});

/// Every pregnancy on the self profile (active and closed), newest first,
/// live. Empty while signed out.
final StreamProvider<List<Pregnancy>> pregnanciesProvider = pregnanciesOfProvider(null);

/// The pregnancy being tracked for mother `motherId` (null = self), or null.
/// Null while loading too — check [pregnanciesOfProvider] to tell the two
/// apart.
final ProviderFamily<Pregnancy?, HealthProfileId?> activePregnancyOfProvider =
    Provider.family<Pregnancy?, HealthProfileId?>(
  (ref, motherId) => ref.watch(pregnanciesOfProvider(motherId)).value?.where((p) => p.isActive).firstOrNull,
);

/// The account holder's own pregnancy being tracked, or null.
final Provider<Pregnancy?> activePregnancyProvider = activePregnancyOfProvider(null);

/// The babies of pregnancy `id` — active, born and no longer followed —
/// live.
final StreamProviderFamily<List<PregnancyBaby>, PregnancyId> pregnancyBabiesProvider =
    StreamProvider.family<List<PregnancyBaby>, PregnancyId>(
  (ref, id) => ref.watch(pregnancyBabiesPortProvider).watchBabies(id),
);

/// Which pregnancy's items to read: its id and the mother's profile, the
/// partition they live in. Build one with `PregnancyItemsKey.itemsKey`.
typedef PregnancyItemsKey = ({PregnancyId id, HealthProfileId mother});

extension PregnancyItemsKeyOf on Pregnancy {
  PregnancyItemsKey get itemsKey => (id: id, mother: motherId);
}

/// The items of a pregnancy, newest first, live.
final StreamProviderFamily<List<PregnancyItem>, PregnancyItemsKey> pregnancyItemsProvider =
    StreamProvider.family<List<PregnancyItem>, PregnancyItemsKey>(
  (ref, key) => ref.watch(pregnanciesDataSourceProvider).watchItems(key.id, scope: key.mother),
);

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
    if (!ref.mounted) return;
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

final watchPregnancyGuidanceUseCaseProvider = Provider<WatchPregnancyGuidanceUseCase>(
  (ref) => WatchPregnancyGuidanceUseCase(source: ref.watch(pregnancyGuidanceSourceProvider)),
);

/// Weekly guidance: the copy on the device first, then the server's if newer.
/// Null (or an error) means there is none to show. Invalidate it to ask the
/// server again — the app does so each time the pregnancy screen opens.
final pregnancyGuidanceProvider = StreamProvider<WeeklyGuidance?>(
  (ref) => ref.watch(watchPregnancyGuidanceUseCaseProvider)(),
);
