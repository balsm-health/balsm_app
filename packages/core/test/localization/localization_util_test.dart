import 'dart:async';
import 'dart:ui' show Locale;

import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Msgs {
  const _Msgs(this.tag);
  final String tag;
}

void main() {
  test('emits the bundle for the initial locale', () {
    final p = LocalizationUtil.getProvider(LocalizedStrings.defaultLangs(
      en: LocaleFactory.sync(() => const _Msgs('en')),
      ar: LocaleFactory.sync(() => const _Msgs('ar')),
    ));
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(p).tag, 'en');
  });

  test('re-emits on locale switch and falls back by language subtag', () {
    final p = LocalizationUtil.getProvider(LocalizedStrings.defaultLangs(
      en: LocaleFactory.sync(() => const _Msgs('en')),
      ar: LocaleFactory.sync(() => const _Msgs('ar')),
    ));
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(p).tag, 'en');
    c.read(currentLocaleProvider.notifier).state =
        const Locale('ar', 'EG'); // ar-EG → ar bundle
    expect(c.read(p).tag, 'ar');
    c.read(currentLocaleProvider.notifier).state = const Locale('fr');
    expect(c.read(p).tag, 'en'); // unknown locale → first registered
  });

  test('deferred locale emits fallback first, real bundle after load', () async {
    final gate = Completer<void>();
    var built = 0;
    final p = LocalizationUtil.getProvider(LocalizedStrings.defaultLangs(
      en: LocaleFactory.sync(() => const _Msgs('en')),
      ar: LocaleFactory.deferred(() => gate.future, () {
        built++;
        return const _Msgs('ar');
      }),
    ));
    final c = ProviderContainer();
    addTearDown(c.dispose);

    c.read(currentLocaleProvider.notifier).state = const Locale('ar');
    expect(c.read(p).tag, 'en'); // still loading → fallback
    expect(built, 0);

    gate.complete();
    await Future<void>.delayed(Duration.zero);
    expect(c.read(p).tag, 'ar'); // swapped in after loadLibrary
    expect(built, 1);

    // Subsequent switches are synchronous (bundle cached).
    c.read(currentLocaleProvider.notifier).state = const Locale('en');
    c.read(currentLocaleProvider.notifier).state = const Locale('ar');
    expect(c.read(p).tag, 'ar');
    expect(built, 1);
  });

  test('all-deferred registry fails loudly on sync resolve', () {
    final strings = LocalizedStrings<_Msgs>({
      const Locale('ar'): LocaleFactory.deferred(
          () async {}, () => const _Msgs('ar')),
    });
    expect(() => strings.resolveSync(const Locale('ar')),
        throwsA(isA<StateError>()));
  });
}
