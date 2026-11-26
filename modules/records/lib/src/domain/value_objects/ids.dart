import 'package:core/core.dart';

import '../../../records.dart' show RecordDocument;

import '../aggregates/record_document.dart' show RecordDocument;

/// Typed id of a [RecordDocument] (vault entry). Minted on-device
/// ([RecordDocumentId.uuid], UUIDv7 with `local-` provenance).
class RecordDocumentId extends UniqueId {
  const RecordDocumentId.value(super.value) : super.value();
  const RecordDocumentId.empty() : super.empty();
  RecordDocumentId.uuid() : super.uuidv7('rec');

  static RecordDocumentId? fromString(String? value) => value.mapNotNull(RecordDocumentId.value);
}
