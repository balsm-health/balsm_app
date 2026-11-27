import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:records/records.dart';

void main() {
  late AppDatabase db;
  HealthProfileId? active;
  late DriftRecordsDataSource ds;
  late UpdateRecordDocumentUseCase update;

  const alice = UserId.value('alice');
  late HealthProfileId aliceSelf;
  const aliceChild = HealthProfileId.value('hp-alice-child');
  const id = RecordDocumentId.value('r1');

  // Synthetic values only — no real-looking PHI.
  RecordDocument doc() => RecordDocument(
        id: id,
        userId: alice,
        type: RecordType.lab,
        title: 'Test title',
        tags: const ['Tag one'],
        fileType: 'PDF',
        filePath: 'vault/r1.pdf',
        pages: 2,
        resultNote: 'Test note',
        takenAt: DateTime.utc(2026, 5, 26),
        createdAt: DateTime.utc(2026, 5, 27),
      );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    aliceSelf = await db.ensureSelfHealthProfile(alice);
    await db.customStatement('INSERT INTO health_profile (id, user_id, is_self, kind, updated_at) '
        "VALUES ('${aliceChild.value}', 'alice', 0, 'dependent', 0)");
    active = aliceSelf;
    ds = DriftRecordsDataSource(db, () => active);
    update = UpdateRecordDocumentUseCase(ds);
  });

  tearDown(() => db.close());

  test('edits title, type and date in place and keeps everything else', () async {
    await ds.put(id, doc());
    final result =
        await update(id, title: '  Edited title  ', type: RecordType.report, takenAt: DateTime.utc(2026, 4, 2));
    expect(result.isSuccess, isTrue);

    final back = (await ds.findAll()).single;
    expect(back.id, id);
    expect(back.title, 'Edited title');
    expect(back.type, RecordType.report);
    expect(back.takenAt, DateTime.utc(2026, 4, 2));
    // Untouched by the edit — the attached file above all.
    expect(back.filePath, 'vault/r1.pdf');
    expect(back.fileType, 'PDF');
    expect(back.pages, 2);
    expect(back.tags, ['Tag one']);
    expect(back.resultNote, 'Test note');
    expect(back.userId, alice);
    expect(back.createdAt, DateTime.utc(2026, 5, 27));
    expect(result.value.title, 'Edited title');
  });

  test('edits the tags when given, trimmed and without blanks or repeats', () async {
    await ds.put(id, doc());
    final result = await update(
      id,
      title: 'Test title',
      type: RecordType.lab,
      takenAt: DateTime.utc(2026, 5, 26, 14, 30),
      tags: [' Tag two ', '', 'Tag three', 'Tag two'],
    );
    expect(result.isSuccess, isTrue);

    final back = (await ds.findAll()).single;
    expect(back.tags, ['Tag two', 'Tag three']);
    expect(back.takenAt, DateTime.utc(2026, 5, 26, 14, 30), reason: 'the time of day is kept too');
    expect(back.filePath, 'vault/r1.pdf');
  });

  test('a blank title is a validation failure and writes nothing', () async {
    await ds.put(id, doc());
    final result = await update(id, title: '   ', type: RecordType.scan, takenAt: DateTime.utc(2026));
    expect(result.error, isA<ValidationFailure>());
    final back = await ds.find(id);
    expect(back!.title, 'Test title');
    expect(back.type, RecordType.lab);
  });

  test('a missing record is not found and an edit never adds a row', () async {
    final result = await update(id, title: 'Edited', type: RecordType.scan, takenAt: DateTime.utc(2026));
    expect(result.error, isA<NotFoundFailure>());
    expect(await ds.findAll(), isEmpty);
  });

  test('edits stay inside the profile partition', () async {
    await ds.put(id, doc());
    active = aliceChild;
    final fromChild = await update(id, title: 'Edited', type: RecordType.scan, takenAt: DateTime.utc(2026));
    expect(fromChild.error, isA<NotFoundFailure>());

    final scoped =
        await update(id, title: 'Edited', type: RecordType.scan, takenAt: DateTime.utc(2026), profile: aliceSelf);
    expect(scoped.isSuccess, isTrue);
    expect((await ds.find(id, scope: aliceSelf))!.title, 'Edited');
    expect(await ds.findAll(), isEmpty);
  });

  test('signed out: nothing to edit', () async {
    await ds.put(id, doc());
    active = null;
    final result = await update(id, title: 'Edited', type: RecordType.scan, takenAt: DateTime.utc(2026));
    // No active profile reads as "not there" — nothing is written.
    expect(result.error, isA<NotFoundFailure>());
    expect((await ds.find(id, scope: aliceSelf))!.title, 'Test title');
  });

  test('watch emits the edited record', () async {
    await ds.put(id, doc());
    final titles = <String?>[];
    final sub = ds.watch(id).listen((r) => titles.add(r?.title));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await update(id, title: 'Edited', type: RecordType.lab, takenAt: DateTime.utc(2026, 5, 26));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(titles.last, 'Edited');
    await sub.cancel();
  });

  group('history', () {
    // A synthetic family member, not a real person.
    final family = ProvenanceActor.other(ProvenanceActorKind.family, displayName: 'Member A');
    final addedByFamily =
        ProvenanceEvent(id: 'p1', actor: family, action: ProvenanceAction.added, at: DateTime.utc(2026, 5));

    test('a record someone else added reads back with its history', () async {
      await ds.put(id, doc().copyWith(history: EntryHistory([addedByFamily])));
      final back = (await ds.findAll()).single;
      expect(back.history.attribution, addedByFamily);
      expect((await ds.find(id))!.history.events, [addedByFamily]);
    });

    test("editing it appends the patient's edit and keeps who added it", () async {
      await ds.put(id, doc().copyWith(history: EntryHistory([addedByFamily])));
      final stamped = UpdateRecordDocumentUseCase(ds, clock: () => DateTime.utc(2026, 6));
      await stamped(id, title: 'Edited', type: RecordType.lab, takenAt: DateTime.utc(2026, 5, 26));

      final events = (await ds.find(id))!.history.events;
      expect(events, hasLength(2));
      expect(events.first, addedByFamily);
      expect(events.last.actor.isSelf, isTrue);
      expect(events.last.action, ProvenanceAction.edited);
      expect(events.last.at, DateTime.utc(2026, 6));
    });

    test("editing the patient's own record leaves it without history", () async {
      await ds.put(id, doc());
      await update(id, title: 'Edited', type: RecordType.lab, takenAt: DateTime.utc(2026, 5, 26));
      expect((await ds.find(id))!.history.isEmpty, isTrue);
    });

    test('storing a copy without history never removes the stored history', () async {
      await ds.put(id, doc().copyWith(history: EntryHistory([addedByFamily])));
      await ds.put(id, doc());
      expect((await ds.find(id))!.history.events, [addedByFamily]);
    });
  });
}
