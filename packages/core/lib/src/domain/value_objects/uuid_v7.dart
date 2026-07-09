import 'dart:typed_data';

import 'package:uuid/parsing.dart';
import 'package:uuid/uuid.dart';

/// Time-ordered RFC 9562 UUIDv7 value object.
///
/// Generation/parsing delegate to the maintained `uuid` package (spec-compliant,
/// **web-safe**, and monotonic within a millisecond). This wrapper keeps a typed
/// API — `.toBytes()` (the 16-byte binary persisted as a SQLCipher BLOB),
/// `.timestamp`, and value equality — so the DB schema and all call sites are
/// unaffected. The canonical byte/string layout is unchanged from the previous
/// hand-rolled implementation, so existing ids remain valid (no migration).
class UuidV7 {
  const UuidV7._(this._bytes);

  final Uint8List _bytes;

  static const _uuid = Uuid();

  static UuidV7 generate() =>
      UuidV7._(UuidParsing.parseAsByteList(_uuid.v7()));

  /// Parse a canonical `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` string.
  /// Throws [FormatException] on malformed input.
  static UuidV7 fromString(String uuid) =>
      UuidV7._(UuidParsing.parseAsByteList(uuid));

  /// Embedded 48-bit unix-ms timestamp. Uses multiplication (values stay under
  /// 2^53) instead of bit shifts, so it is correct under dart2js on web.
  DateTime get timestamp {
    final ms = _bytes[0] * 0x10000000000 +
        _bytes[1] * 0x100000000 +
        _bytes[2] * 0x1000000 +
        _bytes[3] * 0x10000 +
        _bytes[4] * 0x100 +
        _bytes[5];
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  Uint8List toBytes() => Uint8List.fromList(_bytes);

  @override
  String toString() => UuidParsing.unparse(_bytes);

  @override
  bool operator ==(Object other) =>
      other is UuidV7 && toString() == other.toString();

  @override
  int get hashCode => toString().hashCode;
}
