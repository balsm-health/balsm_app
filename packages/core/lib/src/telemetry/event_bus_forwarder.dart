import 'dart:async';

import '../domain/events/app_event.dart';
import '../event_bus/event_bus.dart';
import 'analytics_logger.dart';

/// Domain events whose occurrence is also emitted as a Sentry *event*
/// (searchable/countable milestone), not just a breadcrumb. Keep this to
/// low-volume business/security moments — high-frequency events (e.g. the
/// `dose.*` family) stay breadcrumbs to avoid quota blow-up.
const Set<String> kKeyEventNames = {
  'user_signed_up',
  'user_signed_in',
  'user_signed_out',
  'emergency_qr_token_minted',
  'deletion_requested',
  'deletion_purged',
  'medication.added',
  'blocked_signup_attempted',
  'lockout_triggered',
};

/// Bridges the domain [EventBus] to the [AnalyticsLogger]: every published
/// [AppEvent] becomes a `logEvent(eventName, props: toJson())` (props scrubbed
/// inside the logger). Start once at app boot; stop on teardown.
class EventBusAnalyticsForwarder {
  EventBusAnalyticsForwarder({
    required EventBus bus,
    required AnalyticsLogger analytics,
  })  : _bus = bus,
        _analytics = analytics;

  final EventBus _bus;
  final AnalyticsLogger _analytics;
  StreamSubscription<AppEvent>? _sub;

  void start() {
    _sub ??= _bus.events.listen(_forward);
  }

  void _forward(AppEvent event) {
    _analytics.logEvent(
      event.eventName,
      props: event.toJson(),
      key: kKeyEventNames.contains(event.eventName),
    );
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }
}
