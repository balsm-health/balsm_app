import 'dart:typed_data';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final data = Uint8List.fromList(List<int>.generate(500, (i) => i % 256));

  test('encrypt → decrypt round-trips with the right code', () async {
    final salt = BackupCodec.newSalt();
    final blob = await BackupCodec.encrypt(data, 'CODE-1234', salt: salt);
    expect(blob.length, greaterThan(data.length)); // header + mac overhead
    final back = await BackupCodec.decrypt(blob, 'CODE-1234');
    expect(back, equals(data));
  });

  test('wrong code fails authentication', () async {
    final blob = await BackupCodec.encrypt(data, 'RIGHT', salt: BackupCodec.newSalt());
    expect(
      () => BackupCodec.decrypt(blob, 'WRONG'),
      throwsA(isA<BackupDecryptException>()),
    );
  });

  test('corrupt blob throws, never returns garbage', () async {
    final blob = await BackupCodec.encrypt(data, 'CODE', salt: BackupCodec.newSalt());
    blob[blob.length - 1] ^= 0xFF; // flip a ciphertext byte
    expect(() => BackupCodec.decrypt(blob, 'CODE'), throwsA(isA<BackupDecryptException>()));
  });
}
