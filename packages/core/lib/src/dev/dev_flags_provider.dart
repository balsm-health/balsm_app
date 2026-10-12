import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dev_config_store.dart';

/// The shared Dev Config store.
///
/// A plain [Provider], deliberately NOT a ChangeNotifierProvider: that disposes
/// the notifier it returns, which would tear down a singleton the rest of the
/// app still holds.
final devConfigStoreProvider = Provider<DevConfigStore>((ref) => DevConfigStore.instance);

/// Whether one dev flag is on, rebuilding its watchers when it is toggled.
///
/// Subscribes to the store without owning it — the listener is removed when the
/// provider goes, the store itself lives on.
///
/// Always false in a release build: dev flags are a debugging affordance, and a
/// flag that could change production behaviour would be a way to ship one by
/// accident.
final devFlagProvider = Provider.family<bool, String>((ref, id) {
  const releaseMode = bool.fromEnvironment('dart.vm.product');
  if (releaseMode) return false;

  final store = ref.watch(devConfigStoreProvider);
  void onChanged() => ref.invalidateSelf();
  store.addListener(onChanged);
  ref.onDispose(() => store.removeListener(onChanged));

  return store.flag(id);
});
