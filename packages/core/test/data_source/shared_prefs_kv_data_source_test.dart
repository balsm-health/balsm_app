import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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


  test('exists / delete / clear', () async {
    final kv = await make({'a': 1, 'b': 2});
    expect(await kv.exists('a'), isTrue);
    await kv.delete('a');
    expect(await kv.exists('a'), isFalse);
    await kv.clear();
    expect(await kv.exists('b'), isFalse);
  });

}
