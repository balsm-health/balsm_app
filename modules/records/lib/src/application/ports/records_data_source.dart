import 'package:core/core.dart';

import '../../domain/aggregates/record_document.dart';
import '../../domain/value_objects/ids.dart';

/// Persistence port for the record vault.
///
/// Application code depends on this, never on `DriftRecordsDataSource` — the
/// module's storage engine is an infrastructure detail. Scoped by account
/// (`UserDataSource`), so every read and write is partitioned to the signed-in
/// user without the caller passing an id around.
abstract interface class RecordsDataSource
    implements
        UserDataSource<RecordDocumentId, RecordDocument>,
        WatchableScopedDataSource<RecordDocumentId, RecordDocument, UserId> {}
