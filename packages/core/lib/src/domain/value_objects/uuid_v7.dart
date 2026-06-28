import 'dart:math';
import 'dart:typed_data';

class UuidV7 {
  const UuidV7._(this._bytes);

  final Uint8List _bytes;

  static UuidV7 generate() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rng = Random.secure();
    final bytes = Uint8List(16);
    // 48-bit unix_ts_ms
    bytes[0] = (now >> 40) & 0xFF;
    bytes[1] = (now >> 32) & 0xFF;
    bytes[2] = (now >> 24) & 0xFF;
    bytes[3] = (now >> 16) & 0xFF;
    bytes[4] = (now >> 8) & 0xFF;
    bytes[5] = now & 0xFF;
    // version 7
    bytes[6] = 0x70 | (rng.nextInt(16));
    bytes[7] = rng.nextInt(256);
    // variant + random
    bytes[8] = 0x80 | (rng.nextInt(64));
    for (int i = 9; i < 16; i++) bytes[i] = rng.nextInt(256);
    return UuidV7._(bytes);
  }

  static UuidV7 fromString(String uuid) {
    final hex = uuid.replaceAll('-', '');
    final bytes = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return UuidV7._(bytes);
  }

  DateTime get timestamp {
    final ms = (_bytes[0] << 40) | (_bytes[1] << 32) | (_bytes[2] << 24) |
        (_bytes[3] << 16) | (_bytes[4] << 8) | _bytes[5];
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  Uint8List toBytes() => Uint8List.fromList(_bytes);

  @override
  String toString() {
    final h = _bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  @override
  bool operator ==(Object other) => other is UuidV7 && toString() == other.toString();
  @override
  int get hashCode => toString().hashCode;
}
