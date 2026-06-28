import 'package:core/core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'bootstrap_fake.dart';

/// DEV entrypoint that boots pre-authenticated with seeded demo data.
/// See [bootstrapFake]. Use only with the `dev` flavor.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlavorConfig.init(Flavor.dev);
  final overrides = await bootstrapFake();
  runApp(ProviderScope(overrides: overrides, child: const BalsmApp()));
}
