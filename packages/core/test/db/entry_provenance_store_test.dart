import 'dart:io';

import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late AppDatabase db;
  late HealthProfileId profile;
  late EntryProvenanceStore records;

  // Synthetic values only.
  final family = ProvenanceActor.other(ProvenanceActorKind.family, displayName: 'Member A');
  final clinic = ProvenanceActor.other(ProvenanceActorKind.clinic, careProviderId: 'cp-1');
  final added = ProvenanceEvent(id: 'e1', actor: family, action: ProvenanceAction.added, at: DateTime.utc(2026));
  final shared =
      ProvenanceEvent(id: 'e2', actor: clinic, action: ProvenanceAction.shared, at: DateTime.utc(2026, 1, 2));

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    profile = await db.ensureSelfHealthProfile(const UserId.value('u1'));
    records = EntryProvenanceStore(db, 'health_record');
  });
  tearDown(() => db.close());

  test('append stores new events in order and reads them back', () async {
    await records.append('r1', profile, EntryHistory([added]));
    await records.append('r1', profile, EntryHistory([added, shared]));
    final back = await records.historyOf('r1', profile);
    expect(back, EntryHistory([added, shared]));
    expect(back.events.last.actor.careProviderId, 'cp-1');
  });

  test('a stored event is never rewritten, even when appended again with other content', () async {
    await records.append('r1', profile, EntryHistory([added]));
    final forged = ProvenanceEvent(id: 'e1', actor: clinic, action: ProvenanceAction.edited, at: DateTime.utc(2030));
    await records.append('r1', profile, EntryHistory([forged]));
    expect((await records.historyOf('r1', profile)).events.single, added);
  });

  test('the ledger refuses an update to a stored event', () async {
    await records.append('r1', profile, EntryHistory([added]));
    await expectLater(
      db.customStatement("UPDATE entry_provenance SET actor_name = 'Other' WHERE id = 'e1'"),
      throwsA(anything),
    );
    await expectLater(
      db.customStatement("UPDATE entry_provenance SET action = 'shared' WHERE id = 'e1'"),
      throwsA(anything),
    );
  });

  test('each kind and each profile sees only its own history', () async {
    final other = EntryProvenanceStore(db, 'medications');
    await records.append('x', profile, EntryHistory([added]));
    await other.append('x', profile, EntryHistory([shared]));
    expect((await records.historiesOf(profile)).keys, ['x']);
    expect((await records.historyOf('x', profile)).events.single, added);
    expect((await other.historyOf('x', profile)).events.single, shared);
    expect((await records.historyOf('x', const HealthProfileId.value('someone-else'))).isEmpty, isTrue);
  });

  test('an undecodable row fails loud', () async {
    await db.customStatement('INSERT INTO entry_provenance VALUES '
        "('bad', '${profile.value}', 'health_record', 'r1', 'stranger', 'N', NULL, 'added', '2026-01-01T00:00:00Z')");
    await expectLater(records.historyOf('r1', profile), throwsA(isA<StorageDecodeException>()));
  });

  test('an account merge re-points history to the surviving self profile', () async {
    final target = await db.ensureSelfHealthProfile(const UserId.value('u2'));
    await records.append('r1', profile, EntryHistory([added]));
    await mergeOwner(db, from: 'u1', to: 'u2');
    expect((await records.historyOf('r1', target)).events.single, added);
  });

  test('discarding an account removes its history', () async {
    await records.append('r1', profile, EntryHistory([added]));
    await discardOwner(db, owner: 'u1');
    expect(await db.customSelect('SELECT id FROM entry_provenance').get(), isEmpty);
  });

  test('an existing database gains the ledger when it opens', () async {
    final dir = await Directory.systemTemp.createTemp('balsm_provenance_db');
    final file = File('${dir.path}/legacy.db');
    addTearDown(() => dir.delete(recursive: true));
    sqlite3.open(file.path)
      ..execute('CREATE TABLE health_record (id TEXT PRIMARY KEY, user_id TEXT NOT NULL, type TEXT NOT NULL, '
          'title TEXT NOT NULL, tags TEXT NOT NULL, source TEXT NOT NULL, taken_at TEXT NOT NULL, '
          'created_at TEXT NOT NULL)')
      ..dispose();

    final legacy = AppDatabase(NativeDatabase(file));
    addTearDown(legacy.close);
    final names =
        (await legacy.customSelect("SELECT name FROM sqlite_master WHERE name LIKE '%entry_provenance%'").get())
            .map((r) => r.read<String>('name'));
    expect(names, containsAll(['entry_provenance', 'idx_entry_provenance_entry', 'entry_provenance_no_update']));
  });
}
