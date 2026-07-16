/// Base for immutable value objects — equality by [props], not identity.
///
/// Equality is **type-strict**: two VOs are equal only when they are the
/// exact same runtime type with equal props, so `CurrencyCode('EGP')` never
/// equals some other `String`-backed VO with value `'EGP'`. Hand-rolled (no
/// `equatable` dependency), matching the rest of core.
abstract class ValueObject {
  const ValueObject();

  /// The fields that define equality. Keep small and cheap.
  List<Object?> get props;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ValueObject &&
          other.runtimeType == runtimeType &&
          _propsEqual(other.props, props));

  @override
  int get hashCode => Object.hashAll([runtimeType, ...props]);

  static bool _propsEqual(List<Object?> a, List<Object?> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
