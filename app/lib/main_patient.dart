import 'package:account/account.dart' show buildAccountAdapter;
import 'package:core/core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'patient_app/app_state.dart';
import 'patient_app/prefs.dart';
import 'patient_app/shell.dart';

/// Entrypoint for the claude.ai/design "Patient App" Flutter port.
/// Restores the persisted session so a signed-in user skips the auth flow.
/// Run: flutter run -t lib/main_patient.dart --flavor dev \
///        --dart-define-from-file=env/balsm/dev.json \
///        --dart-define-from-file=env/shared.json
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlavorConfig.initFromEnvironment();

  // Telemetry: crash reporting + user-action analytics via the AnalyticsLogger
  // facade (Sentry backend). See docs/superpowers/specs/2026-07-03-telemetry-*.
  await initSentry();
  // Global KV store (shared_preferences behind the interface) — the only
  // place that constructs it; everything else sees KeyValueDataSource.
  final globalKV = await SharedPrefsKVDataSource.create();
  final container = ProviderContainer(overrides: [
    analyticsLoggerProvider.overrideWithValue(const SentryAnalyticsLogger()),
    // Bind the account module's adapter into core's cross-module read port so
    // other modules (e.g. home) read the account summary without importing it.
    readAccountRepositoryProvider.overrideWith(buildAccountAdapter),
    globalKVDataSourceProvider.overrideWithValue(globalKV),
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

  // T173: country change → refresh locale-derived state. Re-fetches the
  // account summary so greeting/locale-dependent reads reflect the change.
  // App-lifetime subscription, mirrors the forwarder above.
  container.read(eventBusProvider).on<CountryChanged>().listen((_) {
    container.invalidate(accountSummaryProvider);
  });

  // Migrate the app-shell preference group before its first read.
  final paPrefs = PatientAppPrefs(globalKV);
  await paPrefs.migrate();
  final state = await PatientAppState.load(paPrefs);
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
