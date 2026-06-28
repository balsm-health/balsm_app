import 'package:core/core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'bootstrap.dart';

/// Single entrypoint for every brand × env combination. The build is selected
/// entirely by `--dart-define`s — a per-brand/env file plus the shared server
/// list (`env/envs.json`):
///   APP = balsm | balsm_pro      FLAVOR = dev | staging | prod
///
/// Example:
///   flutter run --flavor dev \
///     --dart-define-from-file=env/balsm/dev.json \
///     --dart-define-from-file=env/envs.json
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlavorConfig.initFromEnvironment();
  await initSentry();
  final overrides = await bootstrap();
  runApp(ProviderScope(overrides: overrides, child: const BalsmApp()));
}
