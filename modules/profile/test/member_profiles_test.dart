import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profile/profile.dart';

/// Member (dependent / prenatal) profiles: the domain rules on the aggregate
/// and their persistence next to the self profile. Synthetic data only.
void main() {
  const user = UserId.value('u-members');
  final now = DateTime.utc(2026, 11, 3);

  HealthProfile member({
    String id = 'hp-child',
    ProfileKind kind = ProfileKind.dependent,
    String? name = 'Test Child',
    DateTime? dob,
    Sex? sex,
    PregnancyId? pregnancy,
    int? sequence,
  }) {
    final r = HealthProfile.createMember(
      id: HealthProfileId.value(id),
      userId: user,
      kind: kind,
      displayName: name,
      now: now,
      dateOfBirth: dob,
      sex: sex,
      relationship: Relationship.child,
      pregnancyId: pregnancy,
      sequence: sequence,
    );
    return r.value;
  }

  group('HealthProfile member rules', () {
    test('a dependent with a name is valid', () {
      final r = HealthProfile.createMember(
        id: const HealthProfileId.value('hp-1'),
        userId: user,
        kind: ProfileKind.dependent,
        displayName: '  Test Child ',
        now: now,
        dateOfBirth: DateTime.utc(2020, 1, 1),
        sex: Sex.female,
      );

      expect(r.isSuccess, isTrue);
      expect(r.value.displayName, 'Test Child');
      expect(r.value.isSelf, isFalse);
      expect(r.value.status, ProfileStatus.active);
    });

    test('reports every broken rule at once', () {
      final r = HealthProfile.createMember(
        id: const HealthProfileId.value('hp-1'),
        userId: user,
        kind: ProfileKind.prenatal,
        displayName: 'x' * 61,
        now: now,
        dateOfBirth: DateTime.utc(2027, 1, 1),
        sex: Sex.male,
        sequence: 0,
      );

      expect(r.isFailure, isTrue);
      expect(r.error.message.split(','), [
        'nameTooLong',
        'birthDateInFuture',
        'sexBeforeBirth',
        'birthDateBeforeBirth',
        'pregnancyRequired',
        'invalidSequence',
      ]);
    });

    test('a dependent needs a name; a prenatal profile may wait for one', () {
      expect(
        HealthProfile.createMember(
                id: const HealthProfileId.value('hp-1'),
                userId: user,
                kind: ProfileKind.dependent,
                displayName: ' ',
                now: now)
            .error
            .message,
        'nameRequired',
      );
      expect(
        HealthProfile.createMember(
          id: const HealthProfileId.value('hp-2'),
          userId: user,
          kind: ProfileKind.prenatal,
          displayName: null,
          now: now,
          pregnancyId: const PregnancyId.value('preg-1'),
          sequence: 1,
        ).isSuccess,
        isTrue,
      );
    });

    test('the self profile is not a member and cannot be closed', () {
      expect(
        HealthProfile.createMember(
                id: const HealthProfileId.value('hp-1'),
                userId: user,
                kind: ProfileKind.self,
                displayName: 'Me',
                now: now)
            .error
            .message,
        'selfNotAMember',
      );
      final self = HealthProfile(
        id: const HealthProfileId.value('hp-self'),
        userId: user,
        bloodType: null,
        allergies: const [],
        conditions: const [],
        emergencyContacts: const [],
        updatedAt: now,
      );
      expect(self.close(now).error.message, 'selfCannotClose');
    });

    test('close sets the date once; a closed member no longer changes', () {
      final closed = member().close(DateTime.utc(2026, 11, 3, 15)).value;

      expect(closed.isClosed, isTrue);
      expect(closed.closedOn, DateTime.utc(2026, 11, 3));
      expect(closed.close(now).error.message, 'closed');
      expect(
        closed
            .withMemberDetails(
                displayName: 'Other',
                dateOfBirth: null,
                sex: null,
                relationship: null,
                groupId: null,
                tone: null,
                sequence: null,
                now: now)
            .isFailure,
        isTrue,
      );
    });
  });

  group('DriftProfileDataSource with several profiles', () {
    late AppDatabase db;
    late HealthProfilesDataSource ds;
    late HealthProfileId selfId;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      ds = DriftProfileDataSource(db: db, activeUser: () => user);
      // A member created BEFORE the self row must not be taken for self.
      await ds.createMember(member(id: 'hp-early', name: 'Test Early'));
      selfId = await db.ensureSelfHealthProfile(user);
    });
    tearDown(() => db.close());

    test('getProfile is the self profile, never the first row', () async {
      final self = await ds.getProfile(user);

      expect(self!.id, selfId);
      expect(self.isSelf, isTrue);
      expect((await ds.watchProfile(user).first)!.id, selfId);
    });

    test('lists self first, then members in creation order; closed on request', () async {
      await ds.createMember(member(id: 'hp-late', name: 'Test Late'));
      await ds.closeMember(const HealthProfileId.value('hp-early'), now);

      expect((await ds.findAll()).map((p) => p.id.value), [selfId.value, 'hp-early', 'hp-late']);
      expect((await ds.findMembers()).map((p) => p.id.value), [selfId.value, 'hp-late']);
      expect((await ds.findMembers(includeClosed: true)).map((p) => p.id.value), [selfId.value, 'hp-early', 'hp-late']);
    });

    test('member fields round-trip', () async {
      await ds.createMember(member(
          id: 'hp-baby',
          kind: ProfileKind.prenatal,
          name: null,
          pregnancy: const PregnancyId.value('preg-1'),
          sequence: 2));
      final dob = DateTime.utc(2021, 6, 9);
      final edited = (await ds.find(const HealthProfileId.value('hp-early')))!
          .withMemberDetails(
            displayName: 'Test Renamed',
            dateOfBirth: dob,
            sex: Sex.male,
            relationship: Relationship.neighbour,
            groupId: const MemberGroupId.value('grp-1'),
            tone: 'mint',
            sequence: null,
            now: now,
          )
          .value;

      expect(await ds.updateMember(edited), isTrue);

      final back = (await ds.find(const HealthProfileId.value('hp-early')))!;
      expect(back.kind, ProfileKind.dependent);
      expect(back.displayName, 'Test Renamed');
      expect(back.dateOfBirth, dob);
      expect(back.sex, Sex.male);
      expect(back.relationship, Relationship.neighbour);
      expect(back.groupId, const MemberGroupId.value('grp-1'));
      expect(back.tone, 'mint');
      final baby = (await ds.find(const HealthProfileId.value('hp-baby')))!;
      expect(baby.kind, ProfileKind.prenatal);
      expect(baby.pregnancyId, const PregnancyId.value('preg-1'));
      expect(baby.sequence, 2);
      expect(baby.sex, isNull);
    });

    test('closing refuses self and a second close; the head upsert never reopens', () async {
      expect(await ds.closeMember(selfId, now), isFalse);
      expect(await ds.closeMember(const HealthProfileId.value('hp-early'), now), isTrue);
      expect(await ds.closeMember(const HealthProfileId.value('hp-early'), now), isFalse);

      final closed = (await ds.find(const HealthProfileId.value('hp-early')))!;
      expect(closed.status, ProfileStatus.closed);
      expect(closed.closedOn, now);
      expect(await ds.updateMember(closed), isFalse);
      await ds.put(closed.id, closed.copyWith(weightKg: 20));
      expect((await ds.find(closed.id))!.status, ProfileStatus.closed);
      expect((await ds.getProfile(user))!.id, selfId);
    });

    test('a self aggregate cannot be stored as a member', () async {
      final self = (await ds.getProfile(user))!;
      expect(() => ds.createMember(self.copyWith(id: const HealthProfileId.value('hp-x'))),
          throwsA(isA<StorageWriteException>()));
    });

    test('closing the selected member sends core back to self', () async {
      await db.setActiveHealthProfile(user, const HealthProfileId.value('hp-early'));
      await ds.closeMember(const HealthProfileId.value('hp-early'), now);

      expect(await db.resolveActiveHealthProfile(user), selfId);
    });
  });
}
