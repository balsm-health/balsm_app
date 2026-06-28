import 'package:core/core.dart';
import 'package:flutter/widgets.dart';
import 'patient_app/app_state.dart';
import 'patient_app/shell.dart';

/// Entrypoint for the claude.ai/design "Patient App" Flutter port.
/// Restores the persisted session so a signed-in user skips the auth flow.
/// Run: flutter run -t lib/main_patient.dart --flavor dev \
///        --dart-define-from-file=env/balsm/dev.json \
///        --dart-define-from-file=env/envs.json
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlavorConfig.initFromEnvironment();
  final state = await PatientAppState.load();
  runApp(PatientApp(state: state));
}
