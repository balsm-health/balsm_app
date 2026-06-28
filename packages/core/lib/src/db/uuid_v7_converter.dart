import 'dart:typed_data';
import 'package:drift/drift.dart';
import '../domain/value_objects/uuid_v7.dart';

class UuidV7Converter extends TypeConverter<UuidV7, Uint8List> {
  const UuidV7Converter();

  @override
  UuidV7 fromSql(Uint8List fromDb) => UuidV7.fromString(
        fromDb.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      );

  @override
  Uint8List toSql(UuidV7 value) => value.toBytes();
}
