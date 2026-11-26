import 'package:app/balsm_app/screens/care_provider_draft.dart';
import 'package:core/core.dart' show noProviderRetry;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profile/profile.dart';

/// The Add care provider sheet's draft (type and staged files) and the
/// import banner, without widgets.
void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(retry: noProviderRetry);
    addTearDown(container.dispose);
  });

  group('CareProviderDraftNotifier', () {
    final key = (form: Object(), initial: null);

    test('a file attached in add mode is staged once, and can be taken off', () {
      final n = container.read(careProviderDraftProvider(key).notifier);
      const link = CareProviderFile.link('https://example.test/card');
      n
        ..stage(link)
        ..stage(link);
      expect(container.read(careProviderDraftProvider(key)).staged, [link]);
      n.unstage(link);
      expect(container.read(careProviderDraftProvider(key)).staged, isEmpty);
    });

    test('staging is seen by a listener: the list is a new value each time', () {
      final seen = <int>[];
      container.listen(careProviderDraftProvider(key), (_, next) => seen.add(next.staged.length));
      container.read(careProviderDraftProvider(key).notifier).stage(const CareProviderFile.file('vault/a.jpg'));
      expect(seen, [1]);
    });

    test('the type starts on doctor and changes', () {
      expect(container.read(careProviderDraftProvider(key)).type, CareProviderType.doctor);
      container.read(careProviderDraftProvider(key).notifier).setType(CareProviderType.pharmacy);
      expect(container.read(careProviderDraftProvider(key)).type, CareProviderType.pharmacy);
    });
  });

  test(
    'the import banner shows the count, then clears itself',
    () async {
      final sub = container.listen(careImportBannerProvider, (_, __) {});
      addTearDown(sub.close);
      container.read(careImportBannerProvider.notifier).show(3);
      expect(container.read(careImportBannerProvider), 3);
      await Future<void>.delayed(CareImportBannerNotifier.shownFor + const Duration(milliseconds: 50));
      expect(container.read(careImportBannerProvider), 0);
    },
    timeout: const Timeout(Duration(seconds: 15)),
  );
}
