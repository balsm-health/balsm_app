import 'dart:async';

import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:family/family.dart';
import 'package:flutter_test/flutter_test.dart';

/// `member_group` persistence and the family use cases. The member profiles
/// themselves live behind [FamilyMembersPort] (bound to the profile module in
/// the app); here an in-memory fake stands in for it. Synthetic data only.
class _FakeMembers implements FamilyMembersPort {
  final members = <FamilyMember>[];
  final calls = <String>[];
  final _changes = StreamController<List<FamilyMember>>.broadcast();

  @override
  Stream<List<FamilyMember>> watchMembers() => _changes.stream;

  @override
  Future<List<FamilyMember>> listMembers() async => List.of(members);

  @override
  Future<AppResult<FamilyMember>> createMember(MemberDraft draft,
      {required MemberGroupId? groupId, required MemberTone tone, required DateTime now}) async {
    final m = FamilyMember(
      id: HealthProfileId.value('hp-${members.length}'),
      kind: ProfileKind.dependent,
      displayName: draft.displayName.trim(),
      dateOfBirth: draft.dateOfBirth,
      sex: draft.sex,
      relationship: draft.relationship,
      groupId: groupId,
      tone: tone,
    );
    members.add(m);
    return AppResult.success(m);
  }

  @override
  Future<AppResult<FamilyMember>> updateMember(HealthProfileId id, MemberDraft draft,
      {required MemberGroupId? groupId, required DateTime now}) async {
    calls.add('update ${id.value} ${groupId?.value}');
    return AppResult.success(members.firstWhere((m) => m.id == id));
  }

  @override
  Future<AppResult<void>> closeMember(HealthProfileId id, {required DateTime now}) async {
    final i = members.indexWhere((m) => m.id == id);
    if (i < 0) return AppResult.failure(const NotFoundFailure());
    members.removeAt(i);
    return AppResult.success(null);
  }
}

void main() {
  const user = UserId.value('u-family');
  const other = UserId.value('u-other');
  final now = DateTime(2026, 11, 3);
  late AppDatabase db;
  late DriftMemberGroupsDataSource groups;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    groups = DriftMemberGroupsDataSource(db: db, activeUser: () => user);
  });
  tearDown(() => db.close());

  MemberDraft draft({String? newGroup, MemberGroupId? group, String name = 'Test Child'}) => MemberDraft(
        displayName: name,
        relationship: Relationship.child,
        dateOfBirth: DateTime(2022, 6, 1),
        sex: Sex.male,
        groupId: group,
        newGroupName: newGroup,
      );

  group('DriftMemberGroupsDataSource', () {
    test('default groups round-trip by key, partitioned by account', () async {
      await groups.putBulk({for (final g in MemberGroup.defaults(user, now)) g.id: g});

      final mine = await groups.findAll();
      expect(mine.map((g) => g.defaultGroup), [DefaultGroup.family, DefaultGroup.neighbours]);
      expect(mine.map((g) => g.name), [null, null]);
      expect(await groups.findAll(scope: other), isEmpty);
      expect(await groups.find(mine.first.id, scope: other), isNull);
    });

    test('delete is soft: the row stays but is no longer listed', () async {
      final g = MemberGroup.custom(userId: user, name: 'Work mates', afterSort: 1, now: now).value;
      await groups.put(g.id, g);
      await groups.delete(g.id);

      expect(await groups.findAll(), isEmpty);
      final raw = await db.customSelect('SELECT deleted_at FROM member_group').get();
      expect(raw.single.read<int?>('deleted_at'), isNotNull);
    });

    test('watchAll re-emits after a write', () async {
      final seen = <int>[];
      final sub = groups.watchAll().listen((rows) => seen.add(rows.length));
      await pumpEventQueue();
      final g = MemberGroup.custom(userId: user, name: 'Work mates', afterSort: 1, now: now).value;
      await groups.put(g.id, g);
      await pumpEventQueue();
      await sub.cancel();
      expect(seen, [0, 1]);
    });

    test('signed out: reads are empty and writes refuse', () async {
      final out = DriftMemberGroupsDataSource(db: db, activeUser: () => null);
      expect(await out.findAll(), isEmpty);
      final g = MemberGroup.custom(userId: user, name: 'X', afterSort: 0, now: now).value;
      expect(() => out.put(g.id, g), throwsA(isA<NoActiveUserException>()));
      await out.clear();
    });
  });

  group('EnsureDefaultGroupsUseCase', () {
    test('creates the defaults once per account', () async {
      final ensure = EnsureDefaultGroupsUseCase(groups);
      await ensure(user, now: now);
      await ensure(user, now: now);
      await ensure(other, now: now);

      expect((await groups.findAll()).length, 2);
      expect((await groups.findAll(scope: other)).length, 2);
    });
  });

  group('SaveFamilyMemberUseCase', () {
    late _FakeMembers members;
    late SaveFamilyMemberUseCase save;

    setUp(() {
      members = _FakeMembers();
      save = SaveFamilyMemberUseCase(members: members, groups: groups);
    });

    test('refuses an incomplete form with every broken rule, storing nothing', () async {
      final r = await save.add(const MemberDraft(displayName: '', relationship: null, dateOfBirth: null, sex: null),
          userId: user, now: now);
      expect(r.error.message, 'nameRequired,relationshipRequired,birthDateRequired,sexRequired');
      expect(members.members, isEmpty);
    });

    test('gives each new member the next tone', () async {
      await save.add(draft(name: 'Test One'), userId: user, now: now);
      final second = await save.add(draft(name: 'Test Two'), userId: user, now: now);
      expect(members.members.first.tone, MemberTone.aqua);
      expect(second.value.tone, MemberTone.emerald);
    });

    test('a typed group is created after the existing ones and the member filed in it', () async {
      await EnsureDefaultGroupsUseCase(groups)(user, now: now);
      final r = await save.add(draft(newGroup: 'Work mates'), userId: user, now: now);

      final all = await groups.findAll();
      expect(all.last.name, 'Work mates');
      expect(all.last.sort, 2);
      expect(r.value.groupId, all.last.id);
    });

    test('update files the member under the chosen group', () async {
      final added = await save.add(draft(), userId: user, now: now);
      await save.update(added.value.id, draft(group: const MemberGroupId.value('g-nb')), userId: user, now: now);
      expect(members.calls, ['update hp-0 g-nb']);
    });
  });

  group('CloseFamilyMemberUseCase', () {
    test('refreshes the active profile only when a member was closed', () async {
      final members = _FakeMembers();
      var refreshed = 0;
      final close = CloseFamilyMemberUseCase(members: members, refreshActive: () => refreshed++);
      final added =
          await SaveFamilyMemberUseCase(members: members, groups: groups).add(draft(), userId: user, now: now);

      expect((await close(added.value.id, now: now)).isSuccess, isTrue);
      expect((await close(added.value.id, now: now)).isSuccess, isFalse);
      expect(refreshed, 1);
    });
  });
}
