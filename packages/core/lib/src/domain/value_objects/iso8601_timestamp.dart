class Iso8601Timestamp {
  const Iso8601Timestamp._(this._ms);

  factory Iso8601Timestamp.fromDateTime(DateTime dt) => Iso8601Timestamp._(dt.toUtc().millisecondsSinceEpoch);

  factory Iso8601Timestamp.fromString(String s) => Iso8601Timestamp.fromDateTime(DateTime.parse(s));

  factory Iso8601Timestamp.now() => Iso8601Timestamp.fromDateTime(DateTime.now());

  final int _ms;

  DateTime toDateTime() => DateTime.fromMillisecondsSinceEpoch(_ms, isUtc: true);
  String toIso8601String() => toDateTime().toIso8601String();

  @override
  String toString() => toIso8601String();
  @override
  bool operator ==(Object other) => other is Iso8601Timestamp && _ms == other._ms;
  @override
  int get hashCode => _ms.hashCode;
}
