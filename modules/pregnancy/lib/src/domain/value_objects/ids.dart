import 'package:core/core.dart';

// PregnancyId lives in core — the profile aggregate stores it on a baby's
// profile. Re-exported so module-internal imports of `ids.dart` resolve it.
export 'package:core/core.dart' show PregnancyId;

/// Typed id of a [PregnancyItem] — something recorded during a pregnancy.
class PregnancyItemId extends UniqueId {
  const PregnancyItemId.value(super.value) : super.value();
  const PregnancyItemId.empty() : super.empty();
  PregnancyItemId.uuid() : super.uuidv7('pgi');

  static PregnancyItemId? fromString(String? value) => value?.mapNotNull((v) => PregnancyItemId.value(v));
}
