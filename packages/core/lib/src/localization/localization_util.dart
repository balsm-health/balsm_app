import 'dart:async';
import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Active-locale holder — **pure Dart, no riverpod**, so any layer (use
/// cases, infrastructure, notification builders) may read it. The app shell
/// is the only writer ([setLocale] at bootstrap and on language switch).
///
/// Memory note: the statics here are a [Locale], one broadcast controller,
/// and canonicalized const bundles — app-lifetime by design, nothing worth
/// evicting. The one obligation statics DO impose: every [stream] subscriber
/// must cancel (the riverpod adapter below does; match it if you subscribe
/// manually).
abstract class LocalizationUtil {
  LocalizationUtil._();

  static Locale _current = const Locale('en');
  // sync: listeners (StringsProviders) see the change in the same turn a
  // widget calls setLocale — no one-microtask flash of the previous locale.
  static final _controller = StreamController<Locale>.broadcast(sync: true);

  static Locale get currentLocale => _current;

  /// Locale changes (distinct). Cancel your subscription.
  static Stream<Locale> get stream => _controller.stream;

  static void setLocale(Locale locale) {
    if (locale == _current) return;
    _current = locale;
    _controller.add(locale);
  }

  /// Presentation-layer adapter: a locale-reactive provider around a
  /// module's [LocalizedStrings]. Business logic must NOT use this — read
  /// `strings.current` (sync) or `strings.load()` (deferred-safe) instead.
  static StateNotifierProvider<StringsProvider<T>, T> getProvider<T>(
    LocalizedStrings<T> strings,
  ) {
    return StateNotifierProvider<StringsProvider<T>, T>(
      (ref) => StringsProvider<T>(strings),
    );
  }
}

/// Locale-reactive [StateNotifier] emitting the typed bundle. Presentation
/// only; subscribes to [LocalizationUtil.stream] and cancels on dispose.
class StringsProvider<T> extends StateNotifier<T> {
  StringsProvider(this._strings) : super(_strings.current) {
    _subscription = LocalizationUtil.stream.listen(_apply);
    _apply(LocalizationUtil.currentLocale); // kick deferred load if needed
  }

  final LocalizedStrings<T> _strings;
  late final StreamSubscription<Locale> _subscription;

  /// Monotonic switch counter. A deferred load only applies its result if no
  /// newer switch happened while it was in flight — otherwise a slow
  /// `loadLibrary` would overwrite the locale the user switched to meanwhile.
  int _epoch = 0;

  void _apply(Locale locale) {
    final epoch = ++_epoch;
    final sync = _strings.resolveSyncOrNull(locale);
    if (sync != null) {
      state = sync;
      return;
    }
    state = _strings.resolveSync(locale); // fallback while loading
    _strings.loadFor(locale).then((loaded) {
      if (mounted && epoch == _epoch) state = loaded;
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// A set of per-locale factories for one generated bundle type [T], with
/// lazy construction, deferred-library support, and language-subtag fallback
/// (`ar-EG` → `ar`) then first-registered-locale fallback.
///
/// Pure Dart — this is the object business logic touches:
///
/// ```dart
/// final m = authStrings.current;          // sync, active locale
/// final m = await authStrings.load();     // deferred-safe, active locale
/// ```
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

  /// Best bundle for the ACTIVE locale available synchronously right now.
  T get current => resolveSync(LocalizationUtil.currentLocale);

  /// Bundle for the ACTIVE locale, awaiting its deferred library if needed.
  Future<T> load() => loadFor(LocalizationUtil.currentLocale);

  LocaleFactory<T> _factoryFor(Locale locale) =>
      _factories[locale] ?? _factories[Locale(locale.languageCode)] ?? _factories.values.first;

  /// The bundle for [locale] if it can be produced without awaiting a
  /// deferred library; null when that locale still needs [loadFor].
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
    throw StateError(
      'LocalizedStrings<$T>: no locale is loadable synchronously; '
      'register at least one non-deferred locale.',
    );
  }

  /// Resolves [locale], awaiting its deferred library when needed.
  Future<T> loadFor(Locale locale) async {
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
      await _load();
      _loaded = true;
    }
    _instance = _create();
  }
}
