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

ProviderContainer _container(FakeMaintenanceApi api, {FeatureFlags? flags, Duration poll = const Duration(hours: 1)}) {
  final c = ProviderContainer(overrides: [
    maintenanceApiProvider.overrideWithValue(api),
    featureFlagsProvider.overrideWithValue(flags ?? FeatureFlags(flags: [AppFlags.maintenance])),
    maintenancePollIntervalProvider.overrideWithValue(poll),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('starts unknown — which pauses nothing — then reads the server', () async {
    final api = FakeMaintenanceApi(mode: 'readonly', message: 'Back soon', endsAt: DateTime.utc(2025, 1, 1, 2));
    final c = _container(api);

    final first = c.read(maintenanceProvider);
    await c.read(maintenanceProvider.notifier).check();

    expect((first.mode, first.pausesActions), (MaintenanceMode.unknown, false));
    expect(
      c.read(maintenanceProvider),
      MaintenanceStatus(mode: MaintenanceMode.readonly, message: 'Back soon', endsAt: DateTime.utc(2025, 1, 1, 2)),
    );
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
}
