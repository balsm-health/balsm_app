import 'package:equatable/equatable.dart';

/// Closed catalog of named values — class-based enum.
///
/// Subclasses expose members as `static const` so they are compile-time
/// constants (`Organ.liver`, `Muscle.chest`). Identity is [value] only.
abstract class BaseEnum<V, E extends BaseEnum<V, E>> extends Equatable {
  const BaseEnum(this.value);

  final V value;

  bool matchAny(List<E> list) => list.contains(this);

  @override
  List<Object?> get props => [value];
}
