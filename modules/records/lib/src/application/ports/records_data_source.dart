import 'package:core/core.dart';

import '../../domain/aggregates/record_document.dart';
import '../../domain/value_objects/ids.dart';

/// Persistence port for the record vault.
///
/// Application code depends on this, never on `DriftRecordsDataSource` — the
/// module's storage engine is an infrastructure detail. Scoped by the PERSON
/// the records are about (`ProfileDataSource`, partition = health profile),
/// so every read and write follows the active profile (core's
/// `currentProfileIdProvider`) without the caller passing an id around. The
/// account that recorded a document stays on it as `RecordDocument.userId`.
abstract interface class RecordsDataSource
    implements
        ProfileDataSource<RecordDocumentId, RecordDocument>,
        WatchableScopedDataSource<RecordDocumentId, RecordDocument, HealthProfileId> {}
