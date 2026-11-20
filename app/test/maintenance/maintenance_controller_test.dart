import 'package:app/balsm_app/flags.dart';
import 'package:app/balsm_app/maintenance/maintenance_controller.dart';
import 'package:balsm_api/balsm_api.dart' show ApiException;
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FlagsOff implements FeatureFlagSource {
  @override
  String get name => 'test';

  @override
  Future<void> refresh() async {}

  @override
  Future<bool?> read(String key) async => key == AppFlags.maintenance.key ? false : null;
}

/// The clock the controller reads for a window's first-seen start.
var _clock = DateTime.utc(2025, 1, 1, 0, 30);

ProviderContainer _container(FakeMaintenanceApi api,
    {FeatureFlags? flags, Duration poll = const Duration(hours: 1), FakeManifestMaintenanceSource? manifest}) {
  final c = ProviderContainer(overrides: [
    maintenanceClockProvider.overrideWithValue(() => _clock),
    maintenanceApiProvider.overrideWithValue(api),
    maintenanceNoticeSourceProvider.overrideWithValue(manifest ?? FakeManifestMaintenanceSource()),
    featureFlagsProvider.overrideWithValue(flags ?? FeatureFlags(flags: [AppFlags.maintenance])),
    maintenancePollIntervalProvider.overrideWithValue(poll),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  setUp(() => _clock = DateTime.utc(2025, 1, 1, 0, 30));

  test('starts unknown — which pauses nothing — then reads the server', () async {
    final api = FakeMaintenanceApi(mode: 'readonly', message: 'Back soon', endsAt: DateTime.utc(2025, 1, 1, 2));
    final c = _container(api);

    final first = c.read(maintenanceProvider);
    await c.read(maintenanceProvider.notifier).check();

    expect((first.mode, first.pausesActions), (MaintenanceMode.unknown, false));
    expect(
      c.read(maintenanceProvider),
      MaintenanceStatus(
          mode: MaintenanceMode.readonly, message: 'Back soon', startsAt: _clock, endsAt: DateTime.utc(2025, 1, 1, 2)),
    );
  });

  group('start of the window', () {
    test('the API\'s updated_at, when the API answer wins', () async {
      final c = _container(FakeMaintenanceApi(mode: 'readonly', updatedAt: DateTime.utc(2025, 1, 1)));

      await c.read(maintenanceProvider.notifier).check();

      expect(c.read(maintenanceProvider).startsAt, DateTime.utc(2025, 1, 1));
    });

    test('the manifest\'s starts_at, when the manifest wins', () async {
      final c = _container(FakeMaintenanceApi(mode: 'readonly', updatedAt: DateTime.utc(2025, 1, 1)),
          manifest: FakeManifestMaintenanceSource(
              notice: MaintenanceNotice(mode: 'block', startsAt: DateTime.utc(2024, 12, 31, 23))));

      await c.read(maintenanceProvider.notifier).check();

      expect(c.read(maintenanceProvider).startsAt, DateTime.utc(2024, 12, 31, 23));
    });

    test('otherwise when this app first saw the window; a new end starts a new one', () async {
      final api = FakeMaintenanceApi(mode: 'readonly', endsAt: DateTime.utc(2025, 1, 1, 2));
      final c = _container(api);
      final first = _clock;

      await c.read(maintenanceProvider.notifier).check();
      _clock = _clock.add(const Duration(minutes: 20));
      await c.read(maintenanceProvider.notifier).check();

      expect(c.read(maintenanceProvider).startsAt, first, reason: 'the same window keeps its start');

      api.endsAt = DateTime.utc(2025, 1, 1, 3);
      await c.read(maintenanceProvider.notifier).check();

      expect(c.read(maintenanceProvider).startsAt, _clock);
    });

    test('ending maintenance forgets the window', () async {
      final api = FakeMaintenanceApi(mode: 'readonly');
      final c = _container(api);
      await c.read(maintenanceProvider.notifier).check();

      api.mode = 'off';
      await c.read(maintenanceProvider.notifier).check();
      expect(c.read(maintenanceProvider).startsAt, isNull);

      _clock = _clock.add(const Duration(hours: 1));
      api.mode = 'readonly';
      await c.read(maintenanceProvider.notifier).check();
      expect(c.read(maintenanceProvider).startsAt, _clock);
    });
  });

  test('readonly and block pause actions; only block blocks', () {
    const ro = MaintenanceStatus(mode: MaintenanceMode.readonly);
    const block = MaintenanceStatus(mode: MaintenanceMode.block);
    const off = MaintenanceStatus(mode: MaintenanceMode.off);

    expect([
      ro.pausesActions,
      ro.blocks,
      block.pausesActions,
      block.blocks,
      off.pausesActions
    ], [
      true,
      false,
      true,
      true,
      false,
    ]);
  });

  test('a failed check after a block never keeps the app blocked', () async {
    final api = FakeMaintenanceApi(mode: 'block');
    final c = _container(api);
    await c.read(maintenanceProvider.notifier).check();

    api.failWith = const ApiException(code: 'network_error', isOffline: true);
    await c.read(maintenanceProvider.notifier).check();

    expect(c.read(maintenanceProvider).mode, MaintenanceMode.unknown);
  });

  test('an unrecognised mode is unknown, not a block', () async {
    final c = _container(FakeMaintenanceApi(mode: 'paused'));

    await c.read(maintenanceProvider.notifier).check();

    expect(c.read(maintenanceProvider).pausesActions, isFalse);
  });

  test('with the flag off the server is never asked', () async {
    final api = FakeMaintenanceApi(mode: 'block');
    final flags = FeatureFlags(flags: [AppFlags.maintenance], sources: [_FlagsOff()]);
    await flags.refresh();
    final c = _container(api, flags: flags);

    c.read(maintenanceProvider);
    await c.read(maintenanceProvider.notifier).check();

    expect((c.read(maintenanceProvider).mode, api.calls), (MaintenanceMode.off, 0));
  });

  test('concurrent checks share one request', () async {
    final api = FakeMaintenanceApi();
    final c = _container(api);
    c.read(maintenanceProvider);
    await Future<void>.delayed(Duration.zero);
    final before = api.calls;

    await Future.wait([c.read(maintenanceProvider.notifier).check(), c.read(maintenanceProvider.notifier).check()]);

    expect(api.calls - before, 1);
  });

  test('polls on the interval while listened to', () async {
    final api = FakeMaintenanceApi();
    final c = _container(api, poll: const Duration(milliseconds: 10));
    c.listen(maintenanceProvider, (_, __) {});

    await Future<void>.delayed(const Duration(milliseconds: 55));

    expect(api.calls, greaterThanOrEqualTo(3));
  });

  group('release manifest', () {
    test('a block in the manifest blocks even when the API is unreachable', () async {
      final api = FakeMaintenanceApi()..failWith = const ApiException(code: 'network_error', isOffline: true);
      final manifest = FakeManifestMaintenanceSource(
          notice: MaintenanceNotice(mode: 'block', message: 'Moving servers', endsAt: DateTime.utc(2025, 1, 1, 2)));
      final c = _container(api, manifest: manifest);

      await c.read(maintenanceProvider.notifier).check();

      expect(
        c.read(maintenanceProvider),
        MaintenanceStatus(
            mode: MaintenanceMode.block,
            message: 'Moving servers',
            startsAt: _clock,
            endsAt: DateTime.utc(2025, 1, 1, 2)),
      );
      expect(manifest.calls, greaterThan(0));
    });

    test('the stricter answer wins: a self-hosted server in read-only beats a manifest saying off', () async {
      final c = _container(FakeMaintenanceApi(mode: 'readonly', message: 'Local upgrade'),
          manifest: FakeManifestMaintenanceSource(notice: MaintenanceNotice.off));

      await c.read(maintenanceProvider.notifier).check();

      expect(c.read(maintenanceProvider).mode, MaintenanceMode.readonly);
      expect(c.read(maintenanceProvider).message, 'Local upgrade');
    });

    test('on a tie the manifest message is shown', () async {
      final c = _container(FakeMaintenanceApi(mode: 'block', message: 'server'),
          manifest: FakeManifestMaintenanceSource(notice: const MaintenanceNotice(mode: 'block', message: 'manifest')));

      await c.read(maintenanceProvider.notifier).check();

      expect(c.read(maintenanceProvider).message, 'manifest');
    });

    test('neither source answering pauses nothing', () async {
      final c = _container(FakeMaintenanceApi()..failWith = const ApiException(code: 'network_error', isOffline: true),
          manifest: FakeManifestMaintenanceSource());

      await c.read(maintenanceProvider.notifier).check();

      expect(c.read(maintenanceProvider).mode, MaintenanceMode.unknown);
      expect(c.read(maintenanceProvider).pausesActions, isFalse);
    });

    test('with the flag off the manifest is not read either', () async {
      final manifest = FakeManifestMaintenanceSource(notice: const MaintenanceNotice(mode: 'block'));
      final flags = FeatureFlags(flags: [AppFlags.maintenance], sources: [_FlagsOff()]);
      await flags.refresh();
      final c = _container(FakeMaintenanceApi(), flags: flags, manifest: manifest);

      c.read(maintenanceProvider);
      await c.read(maintenanceProvider.notifier).check();

      expect((c.read(maintenanceProvider).mode, manifest.calls), (MaintenanceMode.off, 0));
    });
  });
}
