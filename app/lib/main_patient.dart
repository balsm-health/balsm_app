import 'package:account/account.dart' show buildAccountAdapter;
import 'package:core/core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  // Telemetry: crash reporting + user-action analytics via the AnalyticsLogger
  // facade (Sentry backend). See docs/superpowers/specs/2026-07-03-telemetry-*.
  await initSentry();
  final container = ProviderContainer(overrides: [
    analyticsLoggerProvider.overrideWithValue(const SentryAnalyticsLogger()),
    // Bind the account module's adapter into core's cross-module read port so
    // other modules (e.g. home) read the account summary without importing it.
    readAccountRepositoryProvider.overrideWith(buildAccountAdapter),
  ]);
  final analytics = container.read(analyticsLoggerProvider);

  // Every framework error → telemetry (still shown in debug console).
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    analytics.logError(
      details.exception,
      stackTrace: details.stack,
      message: details.context?.toString(),
    );
  };
  // Every uncaught async / platform error → telemetry (fatal).
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    analytics.logError(error, stackTrace: stack, fatal: true);
    return true;
  };

  // Every domain AppEvent published on the bus → analytics event/breadcrumb.
  EventBusAnalyticsForwarder(
    bus: container.read(eventBusProvider),
    analytics: analytics,
  ).start();

  final state = await PatientAppState.load();
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: PatientApp(
        state: state,
        navObserver: AnalyticsRouteObserver(analytics),
      ),
    ),
  );
}
