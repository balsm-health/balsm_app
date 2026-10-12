import 'dart:convert';

import 'uuid_v7.dart';
import 'package:equatable/equatable.dart';

/// Identity value object. [value] is the bare id string; [isLocal] flags ids
/// minted on-device (offline, before the server confirms them) so they can be
/// told apart from server-authoritative ids. The provenance ([isLocal],
/// [prefix], [type]) rides in the fields — NOT in [value] — and survives a
/// round-trip only via [storeKey] / [UniqueId.fromJson]; it is deliberately
/// excluded from equality (identity is [value] only).
///
/// Client-minted ids use **UUIDv7** ([UuidV7]) — time-sortable, no MAC address
/// (unlike v1), globally unique at creation (so no id collision offline).
///
/// Note: on sync, replace a local id with the server-authoritative one via
/// [UniqueId.value]; keep sync/dirty state on the *record*, not by rewriting an
/// id already used as a key elsewhere.
class UniqueId extends Id<String> {
  static const key_uuid_v7 = 'uuidv7';
  static const key_timestamp = 'timestamp';
  final bool isLocal;
  final String prefix;
  final String type;
  const UniqueId.value(
    super.value, {
    this.isLocal = false,
    this.prefix = '',
    this.type = UniqueId.key_uuid_v7,
  });

  /// New on-device id: a fresh UUIDv7, [isLocal] until reconciled.
  UniqueId.uuidv7([
    this.prefix = '',
  ])  : type = UniqueId.key_uuid_v7,
        isLocal = true,
        super(UuidV7.generate().toString());

  /// New on-device id backed by an ISO-8601 timestamp, [isLocal] until reconciled.
  UniqueId.timestamp([this.prefix = ''])
      : type = UniqueId.key_timestamp,
        isLocal = true,
        super(_timestampGenerator());

  const UniqueId.empty()
      : isLocal = false,
        type = UniqueId.key_uuid_v7,
        prefix = '',
        super('');

  bool get isEmpty => value.isEmpty;
  bool get isNotEmpty => value.isNotEmpty;

  static UniqueId? fromString(String? id) => id == null ? null : UniqueId.value(id);

  static String _timestampGenerator() => DateTime.now().toIso8601String();

  Map<String, dynamic> toJson() => {
        'type': type,
        if (prefix.trim().isNotEmpty) 'prefix': prefix,
        'isLocal': isLocal,
        'value': value,
      };

  factory UniqueId.fromJson(Map<String, dynamic> json) => UniqueId.value(
        json['value'] as String,
        isLocal: json['isLocal'] as bool? ?? false,
        prefix: json['prefix'] as String? ?? '',
        type: json['type'] as String? ?? UniqueId.key_uuid_v7,
      );

  /// Rich, provenance-carrying serialization for callers that deliberately want
  /// to persist + rehydrate the metadata (round-trips via [UniqueId.fromJson]).
  /// NOT used for identity, routing, or logging — use [value] there.
  String storeKey() => jsonEncode(toJson());

  /// The bare id string — the universal representation (routes, keys, logs,
  /// event payloads). For the metadata-carrying form use [storeKey].
  @override
  String toString() => value;

  @override
  List<Object?> get props => [value];
}

/// Generic typed identifier base. Extend it (usually via [UniqueId]) to get a
/// distinct id type per aggregate — e.g. `class MedicationId extends UniqueId` —
/// so the type system rejects passing one aggregate's id where another's is
/// expected (and it slots straight into `EntityStore<MedicationId, Medication>`).
/// Identity is [value] only.
abstract class Id<T> extends Equatable {
  const Id(this.value);
  final T value;
  @override
  List<Object?> get props => [value];
}
