import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

/// Host driver for `flutter drive`.
///
/// Screenshots land under `build/screenshots/`, which is git-ignored: these are
/// test artefacts, not documentation. The published set lives in
/// `app/screenshots/<brand>/<device>/<lang>/` and is produced by
/// `tool/docshots.dart` — see docs/screenshots.md. Keeping the two apart stops
/// a test run from dropping unscoped files into the brand-scoped tree.
///
/// Override the destination with `SCREENSHOT_DIR` when a run needs them
/// somewhere else.
Future<void> main() async {
  final outDir = Platform.environment['SCREENSHOT_DIR'] ?? 'build/screenshots';
  await integrationDriver(
    onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
      final file = File('$outDir/$name.png');
      await file.create(recursive: true);
      await file.writeAsBytes(bytes);
      return true;
    },
  );
}
