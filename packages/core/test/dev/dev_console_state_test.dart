import 'package:core/core.dart' show noProviderRetry;
import 'package:core/src/dev/dev_console_state.dart';
import 'package:core/src/dev/server_health.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A probe that answers with [result] and records what it was asked.
class _FakeProbe extends ServerHealthProbe {
  _FakeProbe(this.result);
  final ServerHealthResult result;
  final asked = <String>[];

  @override
  Future<ServerHealthResult> check(String baseUrl) async {
    asked.add(baseUrl);
    return result;
  }
}

void main() {
  ProviderContainer containerWith(ServerHealthProbe probe) {
    final c = ProviderContainer(
      retry: noProviderRetry,
      overrides: [serverHealthProvider.overrideWith(() => ServerHealthNotifier(probe))],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('ServerHealthNotifier', () {
    test('a healthy answer reads as ok, with the code, version and time', () async {
      final probe = _FakeProbe(
        const ServerHealthy(statusCode: 200, elapsed: Duration(milliseconds: 82), details: {'version': '1.4.0'}),
      );
      final c = containerWith(probe);
      final sub = c.listen(serverHealthProvider, (_, __) {});
      addTearDown(sub.close);

      final pending = c.read(serverHealthProvider.notifier).check('https://api.example.test');
      expect(c.read(serverHealthProvider).status, ServerHealthStatus.checking);
      await pending;

      final health = c.read(serverHealthProvider);
      expect(health.status, ServerHealthStatus.ok);
      expect(health.message, startsWith('200 OK'));
      expect(health.details, {'version': '1.4.0'});
      expect(probe.asked, ['https://api.example.test']);
    });

    test('an unreachable server fails with its reason, and reset forgets it', () async {
      final c = containerWith(_FakeProbe(const ServerUnreachable('Timed out')));
      final sub = c.listen(serverHealthProvider, (_, __) {});
      addTearDown(sub.close);

      await c.read(serverHealthProvider.notifier).check('https://api.example.test');
      expect(c.read(serverHealthProvider), ServerHealthState(status: ServerHealthStatus.fail, message: 'Timed out'));

      c.read(serverHealthProvider.notifier).reset();
      expect(c.read(serverHealthProvider), ServerHealthState());
    });
  });

  test('BugReportDraftNotifier keeps severity and the screenshot choice apart', () {
    final c = ProviderContainer(retry: noProviderRetry);
    addTearDown(c.dispose);
    final sub = c.listen(bugReportDraftProvider, (_, __) {});
    addTearDown(sub.close);

    c.read(bugReportDraftProvider.notifier)
      ..setSeverity('high')
      ..toggleAttachShot();
    expect(c.read(bugReportDraftProvider), const BugReportDraft(severity: 'high', attachShot: false));
  });
}
