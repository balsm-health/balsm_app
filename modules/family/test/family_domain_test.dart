import 'package:core/core.dart';
import 'package:family/family.dart';
import 'package:flutter_test/flutter_test.dart';

/// Member and group rules of the family context. Synthetic data only.
void main() {
  const user = UserId.value('u-family');
  final now = DateTime(2026, 11, 3);

  FamilyMember member(String id, {String? group, ProfileKind kind = ProfileKind.dependent}) => FamilyMember(
        id: HealthProfileId.value(id),
        kind: kind,
        displayName: 'Test $id',
        groupId: MemberGroupId.fromString(group),
      );

  group('MemberAge', () {
    test('counts completed months, a month short until the day comes round', () {
      expect(MemberAge.between(DateTime(2025, 7, 15), DateTime(2026, 11, 3)), const MemberAge(1, 3));
      expect(MemberAge.between(DateTime(2025, 7, 3), DateTime(2026, 11, 3)), const MemberAge(1, 4));
      expect(MemberAge.between(DateTime(2026, 10, 4), DateTime(2026, 11, 3)), const MemberAge(0, 0));
    });

    test('an adult from the 18th birthday on', () {
      expect(MemberAge.between(DateTime(2008, 11, 4), now).isAdult, isFalse);
      expect(MemberAge.between(DateTime(2008, 11, 3), now).isAdult, isTrue);
    });

    test('a birth date in the future reads as zero', () {
      expect(MemberAge.between(DateTime(2027, 1, 1), now), const MemberAge(0, 0));
    });
  });

  group('FamilyMember', () {
    test('short name is the first word; a child is under 18; unknown age is not a child', () {
      final m = FamilyMember(
        id: const HealthProfileId.value('hp-1'),
        kind: ProfileKind.dependent,
        displayName: '  Test Child Name ',
        dateOfBirth: DateTime(2020, 5, 1),
      );
      expect(m.shortName, 'Test');
      expect(m.isChildOn(now), isTrue);
      expect(member('x').isChildOn(now), isFalse);
    });
  });

  group('MemberDraft', () {
    test('reports every missing field at once', () {
      const draft = MemberDraft(displayName: ' ', relationship: null, dateOfBirth: null, sex: null);
      expect(draft.violations(now), [
        MemberDraftViolation.nameRequired,
        MemberDraftViolation.relationshipRequired,
        MemberDraftViolation.birthDateRequired,
        MemberDraftViolation.sexRequired,
      ]);
    });

    test('refuses a long name and a birth date after today', () {
      final draft = MemberDraft(
        displayName: 'x' * 61,
        relationship: Relationship.child,
        dateOfBirth: DateTime(2026, 11, 4),
        sex: Sex.male,
      );
      expect(draft.violations(now), [MemberDraftViolation.nameTooLong, MemberDraftViolation.birthDateInFuture]);
    });

    test('asks for consent only for an adult', () {
      MemberDraft born(DateTime dob) =>
          MemberDraft(displayName: 'Test', relationship: Relationship.parent, dateOfBirth: dob, sex: Sex.female);
      expect(born(DateTime(1960, 1, 1)).needsConsentOn(now), isTrue);
      expect(born(DateTime(2019, 1, 1)).needsConsentOn(now), isFalse);
    });

    test('a blank new group name creates no group', () {
      const draft = MemberDraft(displayName: 'T', relationship: null, dateOfBirth: null, sex: null, newGroupName: ' ');
      expect(draft.createsGroup, isFalse);
    });
  });

  group('MemberGroup', () {
    test('defaults are family then neighbours, stored by key with no name', () {
      final d = MemberGroup.defaults(user, now);
      expect(d.map((g) => g.defaultGroup), [DefaultGroup.family, DefaultGroup.neighbours]);
      expect(d.map((g) => g.name), [null, null]);
      expect(d.map((g) => g.sort), [0, 1]);
    });

    test('a custom group needs a name of at most 40 characters and goes last', () {
      expect(MemberGroup.custom(userId: user, name: ' ', afterSort: 1, now: now).error.message, 'groupNameRequired');
      expect(
          MemberGroup.custom(userId: user, name: 'x' * 41, afterSort: 1, now: now).error.message, 'groupNameTooLong');
      final ok = MemberGroup.custom(userId: user, name: ' Work mates ', afterSort: 1, now: now).value;
      expect(ok.name, 'Work mates');
      expect(ok.sort, 2);
      expect(ok.isDefault, isFalse);
    });
  });

  group('MemberTone', () {
    test('cycles through the palette and round-trips its code', () {
      expect(MemberTone.forIndex(0), MemberTone.aqua);
      expect(MemberTone.forIndex(5), MemberTone.aqua);
      expect(MemberTone.forIndex(6), MemberTone.emerald);
      expect(MemberTone.tryFromWire('violet'), MemberTone.violet);
      expect(MemberTone.tryFromWire('nope'), isNull);
    });
  });

  group('groupFamily', () {
    final family = MemberGroup(
        id: const MemberGroupId.value('g-fam'),
        userId: user,
        sort: 0,
        createdAt: now,
        defaultGroup: DefaultGroup.family);
    final neighbours = MemberGroup(
        id: const MemberGroupId.value('g-nb'),
        userId: user,
        sort: 1,
        createdAt: now,
        defaultGroup: DefaultGroup.neighbours);
    final work = MemberGroup(id: const MemberGroupId.value('g-work'), userId: user, sort: 2, createdAt: now, name: 'W');

    test('groups in display order, members in given order, empty groups left out', () {
      final sections = groupFamily([
        work,
        neighbours,
        family
      ], [
        member('a', group: 'g-nb'),
        member('b', group: 'g-fam'),
        member('c', group: 'g-nb'),
      ]);
      expect(sections.map((s) => s.group.id.value), ['g-fam', 'g-nb']);
      expect(sections[1].members.map((m) => m.id.value), ['a', 'c']);
    });

    test('a member with no or an unknown group joins the family group', () {
      final sections = groupFamily([family, neighbours], [member('a'), member('b', group: 'g-gone')]);
      expect(sections.single.group.id.value, 'g-fam');
      expect(sections.single.members.length, 2);
    });

    test('a duplicated default group folds into the first one', () {
      final twin = MemberGroup(
          id: const MemberGroupId.value('g-fam-2'),
          userId: user,
          sort: 5,
          createdAt: now,
          defaultGroup: DefaultGroup.family);
      final sections = groupFamily([family, twin], [member('a', group: 'g-fam-2'), member('b', group: 'g-fam')]);
      expect(sections.single.group.id.value, 'g-fam');
      expect(sections.single.members.map((m) => m.id.value), ['a', 'b']);
    });
  });
}
