import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:records/records.dart';

/// A record is UI state: Riverpod 3 drops an update that compares equal to the
/// value it already holds, so an edit of the same record (same id) has to
/// compare unequal or its detail screen never refreshes. Synthetic data only.
void main() {
  RecordDocument record({String title = 'Test record', List<String> tags = const ['Tag one']}) => RecordDocument(
        id: const RecordDocumentId.value('r-1'),
        userId: const UserId.value('u-1'),
        type: RecordType.lab,
        title: title,
        tags: tags,
        takenAt: DateTime(2026, 6, 12, 14, 30),
        createdAt: DateTime(2026, 6, 12),
      );

  test('the same content is equal, and hashes alike', () {
    expect(record(), record());
    expect(record().hashCode, record().hashCode);
  });

  test('an edit of the same record is a different value', () {
    expect(record(), isNot(record(title: 'Edited record')));
    expect(record(), isNot(record(tags: const ['Tag two'])));
    expect(record(), isNot(record().copyWith(type: RecordType.scan)));
    expect(record(), isNot(record().copyWith(takenAt: DateTime(2026, 6, 13))));
  });
}
