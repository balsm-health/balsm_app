import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

/// What a flag resolves to, whichever tool serves it. The vendor adapters are
/// thin; the rules that must never break — a dead source changes nothing,
/// production ignores overrides, the last known value survives a restart —
/// live in [FeatureFlags] and are pinned here.
class _Source implements FeatureFlagSource {
  _Source(this.name, this.values);

  @override
  final String name;
  Map<String, bool> values;
  bool down = false;
  int refreshes = 0;

  @override
  Future<void> refresh() async {
    refreshes++;
    if (down) throw StateError('offline');
  }

  @override
  Future<bool?> read(String key) async => values[key];
}

class _Store implements KeyValueDataSource {
  final map = <String, Object?>{};

  @override
  Future<T?> get<T>(String key) async => map[key] as T?;
  @override
  Future<bool> exists(String key) async => map.containsKey(key);
  @override
  Future<void> put<T>(String key, T value) async => map[key] = value;
  @override
  Future<void> delete(String key) async => map.remove(key);
  @override
  Future<void> clear() async => map.clear();
}

const _off = FeatureFlag('alpha', fallback: false, label: 'Alpha');
const _on = FeatureFlag('beta', fallback: true, label: 'Beta');

void main() {
  test('with no source and no override a flag is its fallback', () {
    final flags = FeatureFlags(flags: const [_off, _on]);
    expect(flags.isOn(_off), isFalse);
    expect(flags.isOn(_on), isTrue);
    expect(flags.originOf(_off), FlagOrigin.fallback);
  });

  test('a source that knows the flag decides it, either way', () async {
    final flags = FeatureFlags(flags: const [
      _off,
      _on
    ], sources: [
      _Source('remote', {'alpha': true, 'beta': false})
    ]);
    await flags.refresh();
    expect(flags.isOn(_off), isTrue);
    expect(flags.isOn(_on), isFalse);
    expect(flags.originOf(_off), FlagOrigin.source);
    expect(flags.sourceOf(_off), 'remote');
  });

  test('sources are asked in order; one with no opinion passes to the next', () async {
    final flags = FeatureFlags(flags: const [
      _off,
      _on
    ], sources: [
      _Source('first', {'alpha': false}),
      _Source('second', {'alpha': true, 'beta': false}),
    ]);
    await flags.refresh();
    expect(flags.isOn(_off), isFalse, reason: 'the first source answered');
    expect(flags.isOn(_on), isFalse, reason: 'only the second knows beta');
    expect(flags.sourceOf(_on), 'second');
  });

  test('listeners hear a change, and only a change', () async {
    final source = _Source('remote', {'alpha': true});
    final flags = FeatureFlags(flags: const [_off], sources: [source]);
    var heard = 0;
    flags.addListener(() => heard++);
    await flags.refresh();
    await flags.refresh();
    expect(heard, 1);
    source.values = {'alpha': false};
    await flags.refresh();
    expect(heard, 2);
  });

  test('a source that is down changes nothing', () async {
    final source = _Source('remote', {'alpha': true});
    final flags = FeatureFlags(flags: const [_off], sources: [source]);
    await flags.refresh();
    source
      ..down = true
      ..values = {};
    await flags.refresh();
    expect(flags.isOn(_off), isTrue, reason: 'the last known value stands while the source is unreachable');
  });

  test('a flag deleted at the source goes back to its fallback', () async {
    final source = _Source('remote', {'alpha': true});
    final flags = FeatureFlags(flags: const [_off], sources: [source]);
    await flags.refresh();
    source.values = {};
    await flags.refresh();
    expect(flags.isOn(_off), isFalse);
    expect(flags.originOf(_off), FlagOrigin.fallback);
  });

  test('the last known values survive a restart with no network', () async {
    final store = _Store();
    final first = FeatureFlags(flags: const [
      _off
    ], sources: [
      _Source('remote', {'alpha': true})
    ], store: store);
    await first.refresh();

    final next = FeatureFlags(flags: const [_off], sources: [_Source('remote', {})..down = true], store: store);
    await next.load();
    expect(next.isOn(_off), isTrue);
    await next.refresh();
    expect(next.isOn(_off), isTrue);
  });

  test('an override beats the sources, and clearing it gives them back', () async {
    final flags = FeatureFlags(flags: const [
      _off
    ], sources: [
      _Source('remote', {'alpha': true})
    ], allowOverrides: true);
    await flags.refresh();
    await flags.setOverride(_off, false);
    expect(flags.isOn(_off), isFalse);
    expect(flags.originOf(_off), FlagOrigin.override);
    await flags.setOverride(_off, null);
    expect(flags.isOn(_off), isTrue);
  });

  test('production ignores overrides, even one already on disk', () async {
    final store = _Store();
    final dev = FeatureFlags(flags: const [_off], store: store, allowOverrides: true);
    await dev.setOverride(_off, true);

    final prod = FeatureFlags(flags: const [_off], store: store);
    await prod.load();
    expect(prod.isOn(_off), isFalse);
    await prod.setOverride(_off, true);
    expect(prod.isOn(_off), isFalse);
  });

  test('unreadable storage is treated as nothing remembered', () async {
    final store = _Store()
      ..map['balsm.flags.values'] = '{not json'
      ..map['balsm.flags.overrides'] = '{"alpha":"yes","beta":true}';
    final flags = FeatureFlags(flags: const [_off, _on], store: store, allowOverrides: true);
    await flags.load();
    expect(flags.isOn(_off), isFalse, reason: 'a non-boolean value is dropped, not coerced');
    expect(flags.isOn(_on), isTrue);
  });

  test('concurrent refreshes share one run', () async {
    final source = _Source('remote', {'alpha': true});
    final flags = FeatureFlags(flags: const [_off], sources: [source]);
    await Future.wait([flags.refresh(), flags.refresh(), flags.refresh()]);
    expect(source.refreshes, 1);
  });

  group('StaticFlagSource', () {
    test('parses the FEATURE_FLAGS define', () {
      expect(StaticFlagSource.parse('sync=true, sync_care=1 ,x=off,y,z=maybe,=true,,'), {
        'sync': true,
        'sync_care': true,
        'x': false,
        'y': true,
      });
      expect(StaticFlagSource.parse('a=true;b=false'), {'a': true, 'b': false});
      expect(StaticFlagSource.parse(''), isEmpty);
    });

    test('has no opinion on a flag it was not given', () async {
      const source = StaticFlagSource({'alpha': true});
      expect(await source.read('alpha'), isTrue);
      expect(await source.read('beta'), isNull);
    });
  });
}
