import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/aggregates/record_document.dart';
import '../../domain/value_objects/ids.dart';
import '../../infrastructure/drift/records_data_source.dart';
import '../ports/records_data_source.dart';

/// Edits a record's own metadata in place: its [title], [type] and the date
/// it was [takenAt].
///
/// Everything else — the attached file, tags, source, result note and when
/// the entry was first created — is kept from the stored row, so an edit can
/// never orphan or swap the encrypted blob. When someone other than the
/// patient added, edited or shared the record, the edit is appended to its
/// [RecordDocument.history] as the patient's own. A blank title is a
/// [ValidationFailure]; a record that is gone (or filed under another
/// profile) is a [NotFoundFailure]; a storage error is a [StorageFailure].
class UpdateRecordDocumentUseCase {
  const UpdateRecordDocumentUseCase(this._records, {DateTime Function() clock = DateTime.now}) : _clock = clock;

  final RecordsDataSource _records;
  final DateTime Function() _clock;

  /// [profile] is the person the record is filed under (null = the active
  /// profile, which is whose records the caller is showing).
  Future<AppResult<RecordDocument>> call(
    RecordDocumentId id, {
    required String title,
    required RecordType type,
    required DateTime takenAt,
    HealthProfileId? profile,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return AppResult.failure(const ValidationFailure('record title is empty'));
    try {
      final existing = await _records.find(id, scope: profile);
      if (existing == null) return AppResult.failure(const NotFoundFailure('record'));
      final edited = existing.copyWith(
        title: trimmed,
        type: type,
        takenAt: takenAt,
        history: existing.history.stampSelfEdit(_clock()),
      );
      await _records.put(id, edited, scope: profile);
      return AppResult.success(edited);
    } on StorageException catch (e) {
      return AppResult.failure(StorageFailure(e.message));
    }
  }
}

final updateRecordDocumentUseCaseProvider = Provider<UpdateRecordDocumentUseCase>(
  (ref) => UpdateRecordDocumentUseCase(ref.watch(recordsDataSourceProvider)),
);
