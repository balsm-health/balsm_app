import 'package:app/update/update_gate_state.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The update gate's answer lives in a notifier; the cached answer comes
/// first, then the live one.
void main() {
  const available = AppUpdateInfo(status: UpdateStatus.available, installed: '1.0.0', latest: '1.1.0');
  const required = AppUpdateInfo(status: UpdateStatus.required, installed: '1.0.0', latest: '2.0.0');

  ProviderContainer container() {
    final c = ProviderContainer(retry: noProviderRetry);
    addTearDown(c.dispose);
    return c;
  }

  test('on launch the cached answer shows first, then the live one replaces it', () async {
    final c = container();
    final seen = <UpdateStatus>[];
    c.listen(updateGateProvider, (_, next) => seen.add(next.info.status));
    await c.read(updateGateProvider.notifier).refresh(
      (brand: AppBrand.balsm, prefs: null, cached: (_) async => required, check: (_) async => available),
      lang: 'en',
      first: true,
    );
    expect(seen, [UpdateStatus.required, UpdateStatus.available]);
    expect(c.read(updateGateProvider).info.latest, '1.1.0');
  });

  test('with no check and no storage nothing runs', () async {
    final c = container();
    await c.read(updateGateProvider.notifier).refresh(
      (brand: AppBrand.balsm, prefs: null, cached: null, check: null),
      lang: 'en',
    );
    expect(c.read(updateGateProvider), const UpdateGateState());
  });

  test('skipping remembers the offered version', () async {
    final c = container();
    await c.read(updateGateProvider.notifier).refresh(
      (brand: AppBrand.balsm, prefs: null, cached: null, check: (_) async => available),
      lang: 'en',
    );
    await c.read(updateGateProvider.notifier).skip(null);
    expect(c.read(updateGateProvider).skipped, '1.1.0');
  });
}
