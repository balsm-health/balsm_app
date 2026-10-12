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
  setUp(() => LocalizationUtil.setLocale(const Locale('en')));

  group('LocalizedStrings (pure — business-logic surface)', () {
    test('current resolves the active locale synchronously', () {
      final strings = LocalizedStrings.defaultLangs(
        en: LocaleFactory.sync(() => const _Msgs('en')),
        ar: LocaleFactory.sync(() => const _Msgs('ar')),
      );
      expect(strings.current.tag, 'en');
      LocalizationUtil.setLocale(const Locale('ar', 'EG')); // subtag → ar
      expect(strings.current.tag, 'ar');
      LocalizationUtil.setLocale(const Locale('fr')); // unknown → first
      expect(strings.current.tag, 'en');
    });

    test('load() awaits a deferred locale; current falls back meanwhile', () async {
      final gate = Completer<void>();
      var built = 0;
      final strings = LocalizedStrings.defaultLangs(
        en: LocaleFactory.sync(() => const _Msgs('en')),
        ar: LocaleFactory.deferred(() => gate.future, () {
          built++;
          return const _Msgs('ar');
        }),
      );
      LocalizationUtil.setLocale(const Locale('ar'));
      expect(strings.current.tag, 'en'); // not loaded yet → fallback
      final pending = strings.load();
      gate.complete();
      expect((await pending).tag, 'ar');
      expect(strings.current.tag, 'ar'); // cached now
      expect(built, 1);
    });

    test('all-deferred registry fails loudly on sync resolve', () {
      final strings = LocalizedStrings<_Msgs>({
        const Locale('ar'): LocaleFactory.deferred(() async {}, () => const _Msgs('ar')),
      });
      expect(() => strings.resolveSync(const Locale('ar')), throwsA(isA<StateError>()));
    });
  });

  group('StringsProvider (riverpod adapter — presentation surface)', () {
    test('emits initial bundle and re-emits on locale switch', () {
      final p = LocalizationUtil.getProvider(LocalizedStrings.defaultLangs(
        en: LocaleFactory.sync(() => const _Msgs('en')),
        ar: LocaleFactory.sync(() => const _Msgs('ar')),
      ));
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(p).tag, 'en');
      LocalizationUtil.setLocale(const Locale('ar'));
      expect(c.read(p).tag, 'ar');
    });

    test('deferred locale emits fallback first, real bundle after load', () async {
      final gate = Completer<void>();
      final p = LocalizationUtil.getProvider(LocalizedStrings.defaultLangs(
        en: LocaleFactory.sync(() => const _Msgs('en')),
        ar: LocaleFactory.deferred(() => gate.future, () => const _Msgs('ar')),
      ));
      final c = ProviderContainer();
      addTearDown(c.dispose);
      LocalizationUtil.setLocale(const Locale('ar'));
      expect(c.read(p).tag, 'en'); // still loading → fallback
      gate.complete();
      await Future<void>.delayed(Duration.zero);
      expect(c.read(p).tag, 'ar');
    });

    test('stale deferred load does not overwrite a newer locale switch', () async {
      final gate = Completer<void>();
      final p = LocalizationUtil.getProvider(LocalizedStrings.defaultLangs(
        en: LocaleFactory.sync(() => const _Msgs('en')),
        ar: LocaleFactory.deferred(() => gate.future, () => const _Msgs('ar')),
      ));
      final c = ProviderContainer();
      addTearDown(c.dispose);
      LocalizationUtil.setLocale(const Locale('ar'));
      expect(c.read(p).tag, 'en');
      LocalizationUtil.setLocale(const Locale('en')); // switch back mid-load
      gate.complete();
      await Future<void>.delayed(Duration.zero);
      expect(c.read(p).tag, 'en'); // late ar completion must NOT win
    });

    test('disposal cancels the static-stream subscription (no leak)', () {
      final p = LocalizationUtil.getProvider(LocalizedStrings.defaultLangs(
        en: LocaleFactory.sync(() => const _Msgs('en')),
        ar: LocaleFactory.sync(() => const _Msgs('ar')),
      ));
      final c = ProviderContainer();
      final notifier = c.read(p.notifier);
      c.dispose();
      // After container disposal the notifier is unmounted; a locale change
      // must not throw (subscription cancelled, no post-dispose state write).
      expect(notifier.mounted, isFalse);
      LocalizationUtil.setLocale(const Locale('ar'));
    });
  });
}
