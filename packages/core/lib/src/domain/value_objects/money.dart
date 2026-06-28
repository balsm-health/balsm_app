class Money {
  const Money({required this.currencyCode, required this.minorUnits});

  factory Money.egp(int minorUnits) =>
      Money(currencyCode: 'EGP', minorUnits: minorUnits);
  factory Money.sar(int minorUnits) =>
      Money(currencyCode: 'SAR', minorUnits: minorUnits);
  factory Money.aed(int minorUnits) =>
      Money(currencyCode: 'AED', minorUnits: minorUnits);

  final String currencyCode;
  final int minorUnits;

  double get amount => minorUnits / 100;

  @override
  String toString() => '$currencyCode ${amount.toStringAsFixed(2)}';
  @override
  bool operator ==(Object other) =>
      other is Money && currencyCode == other.currencyCode && minorUnits == other.minorUnits;
  @override
  int get hashCode => Object.hash(currencyCode, minorUnits);
}
