class Bcp47Tag {
  const Bcp47Tag._(this.value);

  factory Bcp47Tag(String tag) {
    final normalized = tag.trim();
    return Bcp47Tag._(normalized);
  }

  final String value;

  static const en = Bcp47Tag._('en');
  static const arEG = Bcp47Tag._('ar-EG');
  static const arSA = Bcp47Tag._('ar-SA');
  static const arAE = Bcp47Tag._('ar-AE');

  static const _firstClass = {'en', 'ar-EG', 'ar-SA', 'ar-AE'};

  bool get isFirstClass => _firstClass.contains(value);
  bool get isRtl => value.startsWith('ar');

  Bcp47Tag get fallback => isFirstClass ? this : en;

  @override
  String toString() => value;
  @override
  bool operator ==(Object other) => other is Bcp47Tag && value == other.value;
  @override
  int get hashCode => value.hashCode;
}
