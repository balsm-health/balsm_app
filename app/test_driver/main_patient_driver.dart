import 'package:flutter_driver/driver_extension.dart';
import 'package:app/main_patient.dart' as app;

/// Driver entrypoint for UI verification: enables the Flutter Driver extension
/// so the patient app can be navigated programmatically, then runs the app.
/// Not shipped — lives under test_driver/. Run with `flutter run -t test_driver/main_patient_driver.dart`.
Future<void> main() async {
  enableFlutterDriverExtension();
  await app.main();
}
