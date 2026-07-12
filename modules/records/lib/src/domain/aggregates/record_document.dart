import 'package:core/core.dart';

import '../value_objects/ids.dart';

/// Kind of vault entry.
enum RecordType { lab, scan, report }

/// Where a record came from. `self` marks user uploads; anything else is an
/// opaque provider reference (care-team member id) until the directory
/// context lands.
class RecordSource {
  const RecordSource(this.value);
  static const self = RecordSource('self');
  final String value;
  bool get isSelf => value == 'self';

  @override
  bool operator ==(Object other) =>
      other is RecordSource && other.value == value;
  @override
  int get hashCode => value.hashCode;
}

/// A health-record vault entry — the searchable METADATA of one document
/// (lab result, scan, report). PHI, on-device only (SQLCipher).
///
/// The document bytes are NOT here: [filePath] points into the app documents
/// directory. Metadata and bytes live and die together via the records
/// data source + file store.
class RecordDocument {
  const RecordDocument({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    this.tags = const [],
    this.source = RecordSource.self,
    this.fileType,
    this.filePath,
    this.pages,
    this.resultNote,
    required this.takenAt,
    required this.createdAt,
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
      );

  @override
  bool operator ==(Object other) => other is RecordDocument && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
