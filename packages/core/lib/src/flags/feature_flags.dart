import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data_source/key_value_data_source.dart';

/// One switchable feature.
///
/// Declared once as a `const` and passed around by reference, so a flag is
/// never spelled twice. [key] is the name the flag has in whatever tool serves
/// it: letters, digits and underscores only, because that is the set every
/// vendor accepts.
@immutable
class FeatureFlag {
  const FeatureFlag(this.key, {required this.fallback, required this.label, this.description = ''});

  final String key;

  /// What the flag is when nothing else has a say: no override, no source that
  /// knows it, nothing remembered from an earlier launch. Pick the value that
  /// is safe on a device that has never been online.
  final bool fallback;

  /// Shown in Dev Config.
  final String label;
  final String description;
}

/// A place flag values come from: PostHog, Firebase Remote Config, Branch, a
/// JSON file on our own server, a `--dart-define`.
///
/// This interface is all a vendor has to implement, and the only place a vendor
/// SDK is imported. Nothing that reads a flag knows which tool answered.
abstract class FeatureFlagSource {
  /// Short name for Dev Config and logs, e.g. `posthog`.
  String get name;

  /// Fetches the newest values. May throw: [FeatureFlags.refresh] treats a
  /// failure as "this source has nothing to say right now".
  Future<void> refresh();

  /// The value this source holds for [key], or null when it has no opinion —
  /// the flag is not defined there, or the source is switched off. Null lets
  /// the next source, and then the fallback, decide.
  Future<bool?> read(String key);
}

/// Where a flag's current value came from.
enum FlagOrigin { override, source, fallback }

/// The app's feature flags.
///
/// A value is resolved in this order, first one that answers wins:
///
///  1. a Dev Config override — dev and staging builds only;
///  2. the sources, in the order given — remembered on disk, so the last known
///     answer still holds on a launch with no network;
///  3. the flag's own [FeatureFlag.fallback].
///
/// Reads are synchronous and never touch the network. [refresh] is the only
/// thing that does, and a failed refresh changes nothing.
class FeatureFlags extends ChangeNotifier {
  FeatureFlags({
    List<FeatureFlag> flags = const [],
    List<FeatureFlagSource> sources = const [],
    KeyValueDataSource? store,
    this.allowOverrides = false,
  })  : _flags = List.unmodifiable(flags),
        _sources = List.unmodifiable(sources),
        _store = store;

  /// The instance the running app uses, for Dev Config — which lives outside
  /// the provider tree. Everything else takes it from [featureFlagsProvider].
  static FeatureFlags? current;

  static const _kValues = 'balsm.flags.values';
  static const _kOverrides = 'balsm.flags.overrides';

  final List<FeatureFlag> _flags;
  final List<FeatureFlagSource> _sources;
  final KeyValueDataSource? _store;

  /// Whether Dev Config may force a flag. False in production, where a stored
  /// override is ignored as well as unsettable.
  final bool allowOverrides;

  /// Last answer from the sources, and which source gave it.
  Map<String, bool> _values = {};
  Map<String, String> _answeredBy = {};
  Map<String, bool> _overrides = {};
  Future<void>? _refreshing;

  /// Every flag the app declares, for Dev Config.
  List<FeatureFlag> get flags => _flags;

  bool isOn(FeatureFlag flag) => _override(flag) ?? _values[flag.key] ?? flag.fallback;

  FlagOrigin originOf(FeatureFlag flag) => _override(flag) != null
      ? FlagOrigin.override
      : _values.containsKey(flag.key)
          ? FlagOrigin.source
          : FlagOrigin.fallback;

  /// Name of the source that answered for [flag], when one did.
  String? sourceOf(FeatureFlag flag) => _answeredBy[flag.key];

  /// The Dev Config override for [flag]: true, false, or null for none.
  bool? overrideOf(FeatureFlag flag) => _override(flag);

  bool? _override(FeatureFlag flag) => allowOverrides ? _overrides[flag.key] : null;

  /// Reads what earlier launches remembered. Call once, before the first read
  /// that matters.
  Future<void> load() async {
    _values = _decode(await _read(_kValues));
    _overrides = _decode(await _read(_kOverrides));
    notifyListeners();
  }

  /// Asks every source again. Safe to call often: concurrent calls share one
  /// run, and a source that throws is skipped.
  Future<void> refresh() => _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  Future<void> _refresh() async {
    final live = <FeatureFlagSource>[];
    for (final source in _sources) {
      try {
        await source.refresh();
        live.add(source);
      } catch (_) {
        // Offline, or the vendor is down. Its last answers stay as they are.
      }
    }

    final values = Map.of(_values);
    final answeredBy = Map.of(_answeredBy);
    for (final flag in _flags) {
      bool? value;
      String? by;
      var failed = false;
      for (final source in live) {
        try {
          value = await source.read(flag.key);
        } catch (_) {
          failed = true;
          continue;
        }
        if (value != null) {
          by = source.name;
          break;
        }
      }
      if (value != null) {
        values[flag.key] = value;
        answeredBy[flag.key] = by!;
      } else if (!failed && live.length == _sources.length) {
        // Every source answered, and none knows the flag: it was removed.
        // With any source unreachable, the remembered value stands instead.
        values.remove(flag.key);
        answeredBy.remove(flag.key);
      }
    }

    _answeredBy = answeredBy;
    if (mapEquals(values, _values)) return;
    _values = values;
    notifyListeners();
    await _write(_kValues, values);
  }

  /// Forces [flag] on this device, or clears the override with null. Does
  /// nothing where [allowOverrides] is false.
  Future<void> setOverride(FeatureFlag flag, bool? value) async {
    if (!allowOverrides || _overrides[flag.key] == value) return;
    if (value == null) {
      _overrides.remove(flag.key);
    } else {
      _overrides[flag.key] = value;
    }
    notifyListeners();
    await _write(_kOverrides, _overrides);
  }

  Future<String?> _read(String key) async {
    try {
      return await _store?.get<String>(key);
    } catch (_) {
      return null;
    }
  }

  Future<void> _write(String key, Map<String, bool> map) async {
    try {
      await _store?.put<String>(key, jsonEncode(map));
    } catch (_) {
      // The values still hold for this launch.
    }
  }

  static Map<String, bool> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return {};
      return {
        for (final e in json.entries)
          if (e.key is String && e.value is bool) e.key as String: e.value as bool,
      };
    } catch (_) {
      return {};
    }
  }
}

/// The app's flags. Bare — every flag at its fallback — until the app's
/// bootstrap overrides it with the instance it loaded.
final featureFlagsProvider = Provider<FeatureFlags>((ref) => FeatureFlags());
