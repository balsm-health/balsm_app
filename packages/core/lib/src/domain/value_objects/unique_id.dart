import 'uuid_v7.dart';

/// Identity value object. Wraps a string id and encodes *provenance*: ids minted
/// on-device (offline, before the server confirms them) carry a `local-` prefix
/// so [isLocal] can distinguish them from server-authoritative ids.
///
/// Client-minted ids use **UUIDv7** ([UuidV7]) — time-sortable, no MAC address
/// (unlike v1), globally unique at creation (so no id collision offline).
///
/// Note: on sync, replace a local id with the server-authoritative one via
/// [UniqueId.value]; keep sync/dirty state on the *record*, not by rewriting an
/// id already used as a key elsewhere.
class UniqueId {
  const UniqueId.value(this.value);

  /// New on-device id: `local-uuid:<uuidv7>`. [isLocal] until reconciled.
  UniqueId.uuid([String prefix = '']) : value = '$_localUuidPrefix$prefix${UuidV7.generate()}';

  /// New on-device id backed by a timestamp: `local-tstmp:<iso8601>`.
  UniqueId.timestamp([String prefix = '']) : value = '$_localTimestampPrefix$prefix${_timestampGenerator()}';

  const UniqueId.empty() : value = '';

  /// DO NOT CHANGE THIS PREFIX — identifies locally-minted ids.
  static const _localPrefix = 'local';
  static const _localUuidPrefix = '$_localPrefix-uuid:';
  static const _localTimestampPrefix = '$_localPrefix-tstmp:';

  final String value;

  bool get isEmpty => value.isEmpty;
  bool get isNotEmpty => value.isNotEmpty;

  /// True while this id was minted on-device and not yet reconciled with the
  /// server. Server-authoritative ids carry no prefix.
  bool get isLocal => value.startsWith(_localPrefix);

  static UniqueId? fromString(String? id) => id == null ? null : UniqueId.value(id);

  static String _timestampGenerator() => DateTime.now().toIso8601String();

  String toJson() => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is UniqueId && other.runtimeType == runtimeType && other.value == value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// Generic typed identifier base. Extend to get a distinct id type per
/// aggregate — e.g. `final class MedicationId extends Identifier<UniqueId>` —
/// so the type system rejects passing one aggregate's id where another's is
/// expected (and it slots straight into `EntityStore<MedicationId, Medication>`).
abstract class Identifier<T> {
  const Identifier(this.value);

  final T value;

  @override
  bool operator ==(covariant Identifier<T> other) => other.value == value;

  @override
  int get hashCode => value.hashCode;
}
