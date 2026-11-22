import 'package:core/core.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:marionette_flutter/marionette_flutter.dart';

import '../../debug/marionette_config.dart';
import 'main_balsm.dart';

/// E2E entrypoint: the real app boot with the API layer swapped for in-memory
/// fakes, so the whole first-run path runs with no backend.
///
/// Maestro is black-box and cannot inject anything, so it needs a binary that is
/// already stubbed — this one. Patrol does NOT use this entrypoint; its tests
/// call [bootstrap] directly, which is what lets a single test force one
/// specific failure.
///
/// Marionette: outside release builds the binding is initialised first (it must
/// be the process's binding; `bootstrap`'s own `ensureInitialized` then reuses
/// it), so an agent or `marionette` CLI can drive the app over the VM service.
///
/// Build (iOS simulator):
///   fvm flutter build ios --simulator --debug --flavor balsm \
///     -t lib/brands/balsm/main_e2e.dart \
///     --dart-define-from-file=env/balsm/dev.json \
///     --dart-define-from-file=env/shared.json
Future<void> main() {
  if (!kReleaseMode) MarionetteBinding.ensureInitialized(balsmMarionetteConfiguration());
  return bootstrap(extraOverrides: e2eApiOverrides());
}
