import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Pref {
  const _Pref(this.theme, this.compact);
  final String theme;
  final bool compact;

  Map<String, dynamic> toJson() => {'theme': theme, 'compact': compact};
  static _Pref fromJson(Map<String, dynamic> j) =>
      _Pref(j['theme'] as String, j['compact'] as bool);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPrefsKVDataSource> make([Map<String, Object>? seed]) async {
    SharedPreferences.setMockInitialValues(seed ?? {});
    return SharedPrefsKVDataSource(await SharedPreferences.getInstance());
  }

  test('round-trips every supported primitive type', () async {
    final kv = await make();
    await kv.put('b', true);
    await kv.put('i', 7);
    await kv.put('d', 1.5);
    await kv.put('s', 'x');
    await kv.put('l', <String>['a', 'b']);
    await kv.put('m', <String, dynamic>{'k': 1});

    expect(await kv.get<bool>('b'), isTrue);
    expect(await kv.get<int>('i'), 7);
    expect(await kv.get<double>('d'), 1.5);
    expect(await kv.get<String>('s'), 'x');
    expect(await kv.get<List<String>>('l'), ['a', 'b']);
    expect(await kv.get<Map<String, dynamic>>('m'), {'k': 1});
    expect(await kv.get<String>('missing'), isNull);
  });

  test('present-but-wrong-typed value throws StorageDecodeException', () async {
    final kv = await make({'n': 42});
    expect(() => kv.get<String>('n'), throwsA(isA<StorageDecodeException>()));
    expect(() => kv.get<Map<String, dynamic>>('n'),
        throwsA(isA<StorageDecodeException>()));
  });

  test('corrupt json throws StorageDecodeException, not silent null', () async {
    final kv = await make({'j': '{not json'});
    expect(() => kv.get<Map<String, dynamic>>('j'),
        throwsA(isA<StorageDecodeException>()));
  });

  test('unsupported put type throws StorageWriteException', () async {
    final kv = await make();
    expect(() => kv.put('x', DateTime(2026)),
        throwsA(isA<StorageWriteException>()));
  });

  test('object codec round-trip via putObject/getObject', () async {
    final kv = await make();
    await kv.putObject('pref', const _Pref('dark', true), (p) => p.toJson());
    final back = await kv.getObject('pref', _Pref.fromJson);
    expect(back!.theme, 'dark');
    expect(back.compact, isTrue);
  });

  test('exists / delete / clear', () async {
    final kv = await make({'a': 1, 'b': 2});
    expect(await kv.exists('a'), isTrue);
    await kv.delete('a');
    expect(await kv.exists('a'), isFalse);
    await kv.clear();
    expect(await kv.exists('b'), isFalse);
  });

  test('watch seeds current value and emits on put and delete', () async {
    final kv = await make({'k': 'v0'});
    final seen = <String?>[];
    final sub = kv.watch<String>('k').listen(seen.add);
    await Future<void>.delayed(Duration.zero); // seed
    await kv.put('k', 'v1');
    await kv.delete('k');
    await Future<void>.delayed(Duration.zero);
    expect(seen, ['v0', 'v1', null]);
    await sub.cancel();
  });
}
