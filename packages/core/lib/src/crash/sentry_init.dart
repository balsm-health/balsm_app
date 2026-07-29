import 'package:sentry_flutter/sentry_flutter.dart';
import '../config/flavor.dart';
import '../telemetry/telemetry_scrubber.dart';

Future<void> initSentry() async {
  final dsn = FlavorConfig.current.sentryDsn;
  if (dsn == null || dsn.isEmpty) return;

  const version = String.fromEnvironment('APP_VERSION', defaultValue: '0.0.1');
  const build = String.fromEnvironment('BUILD_NUMBER', defaultValue: '1');
  final flavor = FlavorConfig.current.flavor.name;

  await SentryFlutter.init((options) {
    options.dsn = dsn;
    options.environment = flavor;
    options.release = 'balsm@$version+$build-$flavor';
    // Defence-in-depth: scrub every outbound payload against the canonical
    // non-PHI allowlist. The telemetry logger already scrubs at the source;
    // this catches anything Sentry auto-instrumentation adds.
    options.beforeSend = (event, hint) => _scrub(event);
    options.beforeBreadcrumb = (breadcrumb, hint) => _scrubBreadcrumb(breadcrumb);
  });
}

/// Scrub an outbound event's breadcrumb `data` maps. (Contexts set by the
/// telemetry logger are already scrubbed at the source; `extra` is deprecated
/// and unused by our code, so nothing else needs scrubbing here.)
SentryEvent _scrub(SentryEvent event) {
  final crumbs = event.breadcrumbs;
  if (crumbs != null) {
    event.breadcrumbs = crumbs.map((b) => b.data == null ? b : _scrubbedCrumb(b)).toList();
  }
  return event;
}

Breadcrumb? _scrubBreadcrumb(Breadcrumb? breadcrumb) {
  if (breadcrumb == null || breadcrumb.data == null) return breadcrumb;
  return _scrubbedCrumb(breadcrumb);
}

Breadcrumb _scrubbedCrumb(Breadcrumb b) => Breadcrumb(
      message: b.message,
      category: b.category,
      type: b.type,
      level: b.level,
      timestamp: b.timestamp,
      data: scrubTelemetry(b.data),
    );
