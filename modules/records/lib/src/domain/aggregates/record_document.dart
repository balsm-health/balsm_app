import 'package:core/core.dart';
import 'package:flutter/foundation.dart' show immutable, listEquals;

import '../value_objects/ids.dart';

/// Kind of vault entry.
enum RecordType { lab, scan, report }

/// Where a record came from. `self` marks user uploads; anything else is an
/// opaque provider reference (care-team member id) until the directory
/// context lands.
@immutable
class RecordSource {
  const RecordSource(this.value);
  static const self = RecordSource('self');

  /// Photo attached to a symptom check-in. Stored in the same vault for one
  /// encryption/backup path, but hidden from the main records list — it
  /// belongs to the check-in that owns it, not the document library.
  static const checkIn = RecordSource('check-in');
  final String value;
  bool get isSelf => value == 'self';
  bool get isCheckIn => value == 'check-in';

  @override
  bool operator ==(Object other) => other is RecordSource && other.value == value;
  @override
  int get hashCode => value.hashCode;
}

/// A health-record vault entry — the searchable METADATA of one document
/// (lab result, scan, report). PHI, on-device only (SQLCipher).
///
/// The document bytes are NOT here: [filePath] points into the app documents
/// directory. Metadata and bytes live and die together via the records
/// data source + file store.
@immutable
class RecordDocument {
  const RecordDocument({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.takenAt,
    required this.createdAt,
    this.tags = const [],
    this.source = RecordSource.self,
    this.fileType,
    this.filePath,
    this.pages,
    this.resultNote,
    this.history = EntryHistory.none,
  });

  final RecordDocumentId id;
  final UserId userId;
  final RecordType type;

  /// User-entered title (e.g. "HbA1c — glycated hemoglobin").
  final String title;

  /// Free-form filter tags (e.g. "Diabetes", "Follow-up").
  final List<String> tags;

  final RecordSource source;

  /// Display hint: 'PDF' | 'Image' | … (null until a file is attached).
  final String? fileType;

  /// Relative path of the encrypted document inside the app documents dir.
  final String? filePath;

  final int? pages;

  /// Short human note about the outcome (e.g. "6.8% · slightly above target").
  final String? resultNote;

  /// When the underlying test/scan/report was taken.
  final DateTime takenAt;

  /// When the vault entry was created on this device.
  final DateTime createdAt;

  /// Who other than the patient added, edited or shared this record, and the
  /// patient's own edits since. Append-only; empty for the patient's own.
  final EntryHistory history;

  RecordDocument copyWith({
    RecordType? type,
    String? title,
    List<String>? tags,
    RecordSource? source,
    String? fileType,
    String? filePath,
    int? pages,
    String? resultNote,
    DateTime? takenAt,
    EntryHistory? history,
  }) =>
      RecordDocument(
        id: id,
        userId: userId,
        type: type ?? this.type,
        title: title ?? this.title,
        tags: tags ?? this.tags,
        source: source ?? this.source,
        fileType: fileType ?? this.fileType,
        filePath: filePath ?? this.filePath,
        pages: pages ?? this.pages,
        resultNote: resultNote ?? this.resultNote,
        takenAt: takenAt ?? this.takenAt,
        createdAt: createdAt,
        history: history ?? this.history,
      );

  /// Value equality, not "same id": the record is UI state (a stream provider
  /// follows it), and Riverpod 3 drops an update that compares equal to what it
  /// already holds — so an edit of one record would never reach its detail.
  @override
  bool operator ==(Object other) =>
      other is RecordDocument &&
      other.id == id &&
      other.userId == userId &&
      other.type == type &&
      other.title == title &&
      listEquals(other.tags, tags) &&
      other.source == source &&
      other.fileType == fileType &&
      other.filePath == filePath &&
      other.pages == pages &&
      other.resultNote == resultNote &&
      other.takenAt == takenAt &&
      other.createdAt == createdAt &&
      other.history == history;

  @override
  int get hashCode => Object.hash(
        id,
        userId,
        type,
        title,
        Object.hashAll(tags),
        source,
        fileType,
        filePath,
        pages,
        resultNote,
        takenAt,
        createdAt,
        history,
      );
}
