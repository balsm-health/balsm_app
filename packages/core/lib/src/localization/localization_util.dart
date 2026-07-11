import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The app's active locale. Set by the app shell at bootstrap and whenever
/// the user switches language (e.g. on `LanguageChanged`). Every
/// [StringsProvider] re-emits its typed bundle when this changes, so business
/// logic and UI react without touching `BuildContext`/`Localizations`.
final currentLocaleProvider = StateProvider<Locale>(
  (_) => const Locale('en'),
);

/// Locale-driven typed strings for business logic, one per module/package.
///
/// Each module wraps its generated i69n bundles once, in its
/// `presentation/i18n/i18n.dart`:
///
/// ```dart
/// import 'messages_ar.i69n.dart' deferred as ar; // Arabic loads on demand
///
/// final authStringsProvider = LocalizationUtil.getProvider(
///   LocalizedStrings.defaultLangs(
///     en: LocaleFactory.sync(() => const Messages()),
///     ar: LocaleFactory.deferred(ar.loadLibrary, () => ar.Messages_ar()),
///   ),
/// );
/// ```
///
/// Consumers — use cases, notifiers, screens — just watch the typed bundle:
///
/// ```dart
/// final m = ref.watch(authStringsProvider); // Messages
/// m.lockout.title;                          // compile-time checked
/// ```
abstract class LocalizationUtil {
  LocalizationUtil._();

  /// Builds a locale-reactive provider around a module's [LocalizedStrings].
  /// The emitted value tracks [currentLocaleProvider]; deferred locales emit
  /// the fallback bundle first and re-emit once their library loads.
  static StateNotifierProvider<StringsProvider<T>, T> getProvider<T>(
    LocalizedStrings<T> strings,
  ) {
    return StateNotifierProvider<StringsProvider<T>, T>((ref) {
      final notifier = StringsProvider<T>(
        strings,
        ref.read(currentLocaleProvider),
      );
      ref.listen<Locale>(
        currentLocaleProvider,
        (_, next) => notifier.setLocale(next),
      );
      return notifier;
    });
  }
}

/// Emits the typed bundle for the active locale; re-emits on locale switch
/// and when a deferred locale finishes loading.
class StringsProvider<T> extends StateNotifier<T> {
  StringsProvider(this._strings, Locale initial)
      : super(_strings.resolveSync(initial)) {
    // Kick the async path too: if `initial` is deferred and unloaded we start
    // on the fallback bundle and swap in the real one when it arrives.
    setLocale(initial);
  }

  final LocalizedStrings<T> _strings;

  /// Monotonic switch counter. A deferred load only applies its result if no
  /// newer [setLocale] happened while it was in flight — otherwise a slow
  /// `loadLibrary` would overwrite the locale the user switched to meanwhile.
  int _epoch = 0;

  void setLocale(Locale locale) {
    final epoch = ++_epoch;
    final sync = _strings.resolveSyncOrNull(locale);
    if (sync != null) {
      state = sync;
      return;
    }
    state = _strings.resolveSync(locale); // fallback while loading
    _strings.load(locale).then((loaded) {
      if (mounted && epoch == _epoch) state = loaded;
    });
  }
}

/// A set of per-locale factories for one generated bundle type [T], with
/// lazy construction, deferred-library support, and language-subtag fallback
/// (`ar-EG` → `ar`) then first-registered-locale fallback.
class LocalizedStrings<T> {
  LocalizedStrings(Map<Locale, LocaleFactory<T>> factories)
      : _factories = Map.of(factories),
        assert(factories.isNotEmpty, 'register at least one locale');

  static const arLocale = Locale('ar');
  static const enLocale = Locale('en');

  /// The common Balsm pair — English default plus one Arabic bundle.
  factory LocalizedStrings.defaultLangs({
    required LocaleFactory<T> en,
    LocaleFactory<T>? ar,
  }) =>
      LocalizedStrings({
        enLocale: en,
        if (ar != null) arLocale: ar,
      });

  final Map<Locale, LocaleFactory<T>> _factories;

  LocaleFactory<T> _factoryFor(Locale locale) =>
      _factories[locale] ??
      _factories[Locale(locale.languageCode)] ??
      _factories.values.first;

  /// The bundle for [locale] if it can be produced without awaiting a
  /// deferred library; null when that locale still needs [load].
  T? resolveSyncOrNull(Locale locale) {
    final f = _factoryFor(locale);
    if (f.isReady) return f.instance;
    if (!f.isDeferred) {
      f.build();
      return f.instance;
    }
    return null;
  }

  /// The best bundle available *now*: the locale's own if ready/sync,
  /// otherwise the first ready (or synchronously buildable) fallback.
  T resolveSync(Locale locale) {
    final own = resolveSyncOrNull(locale);
    if (own != null) return own;
    for (final f in _factories.values) {
      if (f.isReady) return f.instance as T;
      if (!f.isDeferred) {
        f.build();
        return f.instance as T;
      }
    }
    // Every locale is deferred and unloaded — force the first to load lazily
    // is impossible synchronously; fail loudly rather than lie.
    throw StateError(
      'LocalizedStrings<$T>: no locale is loadable synchronously; '
      'register at least one non-deferred locale.',
    );
  }

  /// Resolves [locale], awaiting its deferred library when needed.
  Future<T> load(Locale locale) async {
    final f = _factoryFor(locale);
    await f.ensureLoaded();
    return f.instance as T;
  }
}

/// One locale's lazy bundle factory. [LocaleFactory.deferred] carries the
/// `loadLibrary` hook of a `deferred as` import so heavy locales stay out of
/// the initial payload.
class LocaleFactory<T> {
  LocaleFactory.sync(T Function() create)
      : _create = create,
        _load = null;

  LocaleFactory.deferred(Future<void> Function() load, T Function() create)
      : _create = create,
        _load = load;

  final T Function() _create;
  final Future<void> Function()? _load;

  T? _instance;
  bool _loaded = false;

  bool get isDeferred => _load != null;
  bool get isReady => _instance != null;
  T? get instance => _instance;

  /// Synchronous build — only valid for non-deferred factories.
  void build() {
    assert(!isDeferred, 'deferred locales must go through ensureLoaded()');
    _instance ??= _create();
  }

  Future<void> ensureLoaded() async {
    if (_instance != null) return;
    if (_load != null && !_loaded) {
      await _load!();
      _loaded = true;
    }
    _instance = _create();
  }
}
