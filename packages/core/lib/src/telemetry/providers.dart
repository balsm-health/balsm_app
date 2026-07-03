import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'analytics_logger.dart';

/// The app's telemetry facade. Defaults to [NoopAnalyticsLogger]; the app's
/// `ProviderScope` overrides it with `SentryAnalyticsLogger()` after
/// `initSentry()` has run, and starts an `EventBusAnalyticsForwarder` +
/// attaches an `AnalyticsRouteObserver`.
final analyticsLoggerProvider = Provider<AnalyticsLogger>((ref) {
  return const NoopAnalyticsLogger();
});
