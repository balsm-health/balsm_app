import 'dart:typed_data';

import 'package:app/balsm_app/screens/record_draft.dart';
import 'package:app/balsm_app/widgets/photo_attach.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:records/records.dart';

/// The add-record sheet's draft as plain transitions. Synthetic records only.
void main() {
  final at = DateTime(2026, 7, 24, 9);
  final stored = RecordDocument(
    id: const RecordDocumentId.value('rec-1'),
    userId: const UserId.value('user-1'),
    type: RecordType.lab,
    title: 'Lab A',
    takenAt: at,
    createdAt: at,
    tags: const ['tag-a'],
  );

  test('an edit opens on the record; a shortcut on its type; otherwise the picker', () {
    final edit = RecordDraft.from(now: DateTime(2026), initial: stored);
    expect((edit.type, edit.takenAt), (RecordType.lab, at));
    expect(edit.tags, ['tag-a']);
    expect(RecordDraft.from(now: at, initialType: RecordType.scan).type, RecordType.scan);
    expect(RecordDraft.from(now: at).canSave, isFalse);
  });

  test('tags are trimmed, never blank or repeated, and removable', () {
    final d = RecordDraft(takenAt: at).addTag(' tag-b ').addTag('tag-b').addTag('  ');
    expect(d.tags, ['tag-b']);
    expect(d.removeTag('tag-b').tags, isEmpty);
    expect(() => d.tags.add('tag-c'), throwsUnsupportedError);
  });

  test('Back to the picker keeps what was filled in', () {
    final d = RecordDraft(takenAt: at, type: RecordType.lab).addTag('tag-a').withType(null);
    expect(d.type, isNull);
    expect(d.tags, ['tag-a']);
  });

  test('a new pick is a different draft; equal drafts compare equal', () {
    final d = RecordDraft(takenAt: at, type: RecordType.lab, tags: const ['tag-a']);
    expect(d, RecordDraft(takenAt: at, type: RecordType.lab, tags: const ['tag-a']));
    final pick = PickedAttach(kind: 'image', bytes: Uint8List(1));
    expect(d.withAttach(pick), isNot(d));
    expect(d.withDate(at.add(const Duration(hours: 1))), isNot(d));
  });

  test('two sheets never share a draft', () {
    final c = ProviderContainer(retry: noProviderRetry);
    addTearDown(c.dispose);
    final RecordDraftKey a = (form: Object(), initial: stored, initialType: null);
    final RecordDraftKey b = (form: Object(), initial: null, initialType: RecordType.report);
    c
      ..listen(recordDraftProvider(a), (_, __) {})
      ..listen(recordDraftProvider(b), (_, __) {});
    c.read(recordDraftProvider(b).notifier).addTag('tag-z');
    expect(c.read(recordDraftProvider(a)).tags, ['tag-a']);
    expect(c.read(recordDraftProvider(b)).tags, ['tag-z']);
  });
}
