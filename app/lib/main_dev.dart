import 'package:core/core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'bootstrap.dart';
import 'app.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlavorConfig.init(Flavor.dev);
  await initSentry();
  final overrides = await bootstrap();
  runApp(ProviderScope(overrides: overrides, child: const BalsmApp()));
}
