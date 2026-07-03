import 'package:flutter/widgets.dart';

import 'analytics_logger.dart';

/// Logs a `screen_view` action on every navigation. Attach to
/// `MaterialApp.router`'s `observers` (or `Navigator.observers`). Route names
/// are non-PHI paths (e.g. `/account/settings`).
class AnalyticsRouteObserver extends NavigatorObserver {
  AnalyticsRouteObserver(this._analytics);

  final AnalyticsLogger _analytics;

  void _log(Route<dynamic>? route, String transition) {
    final name = route?.settings.name;
    if (name == null) return;
    _analytics.logEvent(
      'screen_view',
      props: {'route': name, 'action': transition},
    );
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _log(route, 'push');
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _log(previousRoute, 'pop');
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _log(newRoute, 'replace');
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}
