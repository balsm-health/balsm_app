import 'package:core/core.dart';

/// Typed id of a [RecordDocument] (vault entry). Minted on-device
/// ([RecordDocumentId.uuid], UUIDv7 with `local-` provenance).
class RecordDocumentId extends UniqueId {
  const RecordDocumentId.value(super.value) : super.value();
  const RecordDocumentId.empty() : super.empty();
  RecordDocumentId.uuid() : super.uuid('rec-');

  static RecordDocumentId? fromString(String? value) =>
      value?.mapNotNull((v) => RecordDocumentId.value(v));
}
