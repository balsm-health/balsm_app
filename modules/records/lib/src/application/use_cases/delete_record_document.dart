import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/aggregates/record_document.dart';
import '../../infrastructure/drift/records_data_source.dart';
import '../ports/records_data_source.dart';

/// Removes a record and the encrypted attachment behind it.
///
/// Both are PHI, and the order matters: the blob goes first so a failed row
/// delete can never leave a readable file with no row pointing at it. Lives in
/// the application layer rather than the sheet that triggers it — the rule is
/// domain policy, not presentation.
class DeleteRecordDocumentUseCase {
  DeleteRecordDocumentUseCase({required this.records, required this.files});

  final RecordsDataSource records;
  final UserFileStore files;

  /// [scope] is the account whose encrypted file store holds the blob;
  /// [profile] the person the record is filed under (null = the active
  /// profile, which is whose records the caller is showing).
  Future<void> call(RecordDocument record, {required UserId scope, HealthProfileId? profile}) async {
    final path = record.filePath;
    if (path != null && path.isNotEmpty) {
      await files.delete(path, scope: scope);
    }
    await records.delete(record.id, scope: profile);
  }
}

final deleteRecordDocumentUseCaseProvider = Provider<DeleteRecordDocumentUseCase>(
  (ref) => DeleteRecordDocumentUseCase(
    records: ref.watch(recordsDataSourceProvider),
    files: ref.watch(userFileStoreProvider),
  ),
);
