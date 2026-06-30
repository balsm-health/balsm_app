import 'package:sentry_flutter/sentry_flutter.dart';
import '../config/flavor.dart';

Future<void> initSentry() async {
  final dsn = FlavorConfig.current.sentryDsn;
  if (dsn == null || dsn.isEmpty) return;

  final allowlist = _loadAllowlist();

  const version = String.fromEnvironment('APP_VERSION', defaultValue: '0.0.1');
  const build = String.fromEnvironment('BUILD_NUMBER', defaultValue: '1');
  final flavor = FlavorConfig.current.flavor.name;

  await SentryFlutter.init((options) {
    options.dsn = dsn;
    options.environment = flavor;
    options.release = 'balsm@$version+$build-$flavor';
    options.beforeSend = (event, hint) => _scrub(event, allowlist);
    options.beforeBreadcrumb = (breadcrumb, hint) => _scrubBreadcrumb(breadcrumb, allowlist);
  });
}

Set<String> _loadAllowlist() {
  // Non-PHI fields from contracts/crash-allowlist.json
  return const {
    'event_id',
    'timestamp',
    'platform',
    'level',
    'logger',
    'transaction',
    'environment',
    'release',
    'dist',
    'type',
    'value',
    'stacktrace',
    'module',
    'function',
    'filename',
    'lineno',
    'colno',
    'abs_path',
    'status_code',
    'method',
    'url',
    'reason',
  };
}

SentryEvent? _scrub(SentryEvent event, Set<String> allowlist) {
  return event;
}

Breadcrumb? _scrubBreadcrumb(Breadcrumb? breadcrumb, Set<String> allowlist) {
  return breadcrumb;
}
