import 'package:core/core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _Recorded {
  _Recorded(this.name, this.props, this.key);
  final String name;
  final Map<String, Object?>? props;
  final bool key;
}

class FakeAnalyticsLogger implements AnalyticsLogger {
  final events = <_Recorded>[];

  @override
  void logEvent(String name, {Map<String, Object?>? props, bool key = false}) {
    events.add(_Recorded(name, props, key));
  }

  @override
  void log(String message, {LogLevel level = LogLevel.info, Map<String, Object?>? props}) {}
  @override
  void logError(Object error, {StackTrace? stackTrace, String? message, Map<String, Object?>? context, bool fatal = false}) {}
  @override
  void setUser(String? id) {}
  @override
  Future<void> flush() async {}
}

class _TestEvent extends AppEvent {
  const _TestEvent(this.eventName, this._json);
  @override
  final String eventName;
  final Map<String, dynamic> _json;
  @override
  Map<String, dynamic> toJson() => _json;
}

void main() {
  test('forwards each published AppEvent as a logEvent', () async {
    final bus = EventBus();
    final logger = FakeAnalyticsLogger();
    final forwarder = EventBusAnalyticsForwarder(bus: bus, analytics: logger)..start();

    bus.publish(const _TestEvent('language_changed', {'newLanguage': 'ar'}));
    await Future<void>.delayed(Duration.zero); // let the broadcast deliver

    expect(logger.events, hasLength(1));
    expect(logger.events.single.name, 'language_changed');
    expect(logger.events.single.props, {'newLanguage': 'ar'});

    await forwarder.stop();
    bus.dispose();
  });

  test('marks key events per kKeyEventNames; others non-key', () async {
    final bus = EventBus();
    final logger = FakeAnalyticsLogger();
    EventBusAnalyticsForwarder(bus: bus, analytics: logger).start();

    bus.publish(const _TestEvent('emergency_qr_token_minted', {}));
    bus.publish(const _TestEvent('dose.taken', {}));
    await Future<void>.delayed(Duration.zero);

    final byName = {for (final e in logger.events) e.name: e.key};
    expect(byName['emergency_qr_token_minted'], isTrue);
    expect(byName['dose.taken'], isFalse);
    bus.dispose();
  });

  test('AnalyticsRouteObserver logs screen_view with route + transition', () {
    final logger = FakeAnalyticsLogger();
    final observer = AnalyticsRouteObserver(logger);

    final route = PageRouteBuilder<void>(
      settings: const RouteSettings(name: '/account/settings'),
      pageBuilder: (_, __, ___) => const SizedBox(),
    );
    observer.didPush(route, null);

    expect(logger.events.single.name, 'screen_view');
    expect(logger.events.single.props,
        {'route': '/account/settings', 'action': 'push'});
  });
}
