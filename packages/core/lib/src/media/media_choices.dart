import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data_source/data_source_providers.dart';

/// The user's pick on each user media axis (`gender` → `boy`), keyed by
/// axis id so one pick applies to every media item with that axis.
/// Remembered on this device only, in the global KV store; never sent to
/// the server or the CDN.
final mediaChoicesProvider = NotifierProvider<MediaChoices, Map<String, String>>(MediaChoices.new);

class MediaChoices extends Notifier<Map<String, String>> {
  /// Global KV key holding the choice for [axisId].
  static String storageKey(String axisId) => 'media.axis_choice.$axisId';

  @override
  Map<String, String> build() => const {};

  /// Reads the remembered choices for [axisIds] not yet known.
  Future<void> load(Iterable<String> axisIds) async {
    final kv = ref.read(globalKVDataSourceProvider);
    for (final id in axisIds.where((id) => !state.containsKey(id)).toSet()) {
      final value = await kv.get<String>(storageKey(id));
      if (!ref.mounted) return;
      if (value != null && !state.containsKey(id)) state = {...state, id: value};
    }
  }

  /// Picks [value] on [axisId] and remembers it.
  Future<void> choose(String axisId, String value) async {
    state = {...state, axisId: value};
    await ref.read(globalKVDataSourceProvider).put<String>(storageKey(axisId), value);
  }
}
