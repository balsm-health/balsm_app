import 'package:core/core.dart';

/// Typed id of a disclosure document (server-defined, versioned separately).
class DisclosureId extends UniqueId {
  const DisclosureId.value(super.value) : super.value();
  const DisclosureId.empty() : super.empty();

  static DisclosureId? fromString(String? value) =>
      value?.mapNotNull((v) => DisclosureId.value(v));
}
