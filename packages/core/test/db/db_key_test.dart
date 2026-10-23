import 'dart:io';
import 'dart:math';

import 'package:core/src/db/db_file_guard_io.dart';
import 'package:core/src/db/db_key.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('is 64 lowercase hex chars', () {
    expect(generateDbKeyHex(), matches(RegExp(r'^[0-9a-f]{64}$')));
  });

  test('is not a repeated byte (regression: microsecond-filled key)', () {
    final key = generateDbKeyHex();
    final bytes = {for (var i = 0; i < 64; i += 2) key.substring(i, i + 2)};
    expect(bytes.length, greaterThan(8));
  });

  test('two keys differ', () {
    expect(generateDbKeyHex(), isNot(generateDbKeyHex()));
  });

  test('uses the given source', () {
    expect(generateDbKeyHex(Random(1)), generateDbKeyHex(Random(1)));
  });

  group('isValidDbKeyHex', () {
    test('accepts a generated key', () => expect(isValidDbKeyHex(generateDbKeyHex()), isTrue));
    test('rejects anything that could break out of the PRAGMA', () {
      expect(isValidDbKeyHex('${'a' * 63}"'), isFalse);
      expect(isValidDbKeyHex('A' * 64), isFalse);
      expect(isValidDbKeyHex('a' * 63), isFalse);
      expect(isValidDbKeyHex('a' * 65), isFalse);
      expect(isValidDbKeyHex(''), isFalse);
    });
  });

  group('prepareDbFileForNewKey', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('db_guard'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('deletes a plaintext SQLite file', () {
      final f = File('${dir.path}/balsm.db')
        ..writeAsBytesSync([...'SQLite format 3\u0000'.codeUnits, ...List.filled(100, 0)]);
      expect(isPlaintextSqlite(f), isTrue);
      prepareDbFileForNewKey(f);
      expect(f.existsSync(), isFalse);
    });

    test('refuses to delete a file that is not plaintext SQLite (an encrypted database)', () {
      final f = File('${dir.path}/balsm.db')..writeAsBytesSync(List.generate(4096, (i) => (i * 37) % 256));
      expect(isPlaintextSqlite(f), isFalse);
      expect(() => prepareDbFileForNewKey(f), throwsStateError);
      expect(f.existsSync(), isTrue);
    });

    test('an empty file is deleted', () {
      final f = File('${dir.path}/balsm.db')..writeAsBytesSync(const []);
      prepareDbFileForNewKey(f);
      expect(f.existsSync(), isFalse);
    });

    test('no file: nothing to do', () {
      expect(() => prepareDbFileForNewKey(File('${dir.path}/none.db')), returnsNormally);
    });
  });
}
