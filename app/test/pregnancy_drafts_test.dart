import 'package:app/balsm_app/screens/pregnancy/pregnancy_drafts.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pregnancy/pregnancy.dart';

/// The pregnancy forms' drafts as plain state transitions and notifiers,
/// with no widget involved. Every value is synthetic.
void main() {
  const pregId = PregnancyId.value('preg-test');
  const mother = HealthProfileId.value('hp-mother');
  const babyA = HealthProfileId.value('hp-baby-a');
  const babyB = HealthProfileId.value('hp-baby-b');

  PregnancyBaby baby(HealthProfileId id, int seq, {String? name}) =>
      PregnancyBaby(id: id, pregnancyId: pregId, sequence: seq, status: BabyStatus.active, name: name);

  PregnancyItem item(String id, List<HealthProfileId> about) => PregnancyItem(
        id: PregnancyItemId.value(id),
        pregnancyId: pregId,
        about: ItemAbout.baby,
        babyIds: about,
        kind: ItemKind.scan,
        recordedOn: DateTime(2020),
        createdAt: DateTime(2020),
      );

  group('PregnancyStartDraft', () {
    test('a due date is the day picked; a last period gives the estimate', () {
      final d = const PregnancyStartDraft().withDate(DateTime(2020, 3));
      expect(d.due, DateTime(2020, 3));
      final lmp = const PregnancyStartDraft().withMode(PregnancyStartMode.lastPeriod).withDate(DateTime(2020));
      expect(lmp.due, PregnancyDates.dueFromLastPeriod(DateTime(2020)));
    });

    test('switching mode clears the day picked, but not the visit or count', () {
      final d = const PregnancyStartDraft()
          .withDate(DateTime(2020, 3))
          .withVisit(DateTime(2020, 1, 10))
          .withCount(2)
          .withMode(PregnancyStartMode.lastPeriod);
      expect((d.date, d.visit, d.count), (null, DateTime(2020, 1, 10), 2));
      expect(d.withMode(PregnancyStartMode.lastPeriod), same(d), reason: 'the same mode changes nothing');
    });

    test('the baby count stays within 1 and the maximum', () {
      expect(const PregnancyStartDraft().withCount(0).count, 1);
      expect(const PregnancyStartDraft().withCount(Pregnancy.maxBabies + 1).count, Pregnancy.maxBabies);
    });
  });

  group('BirthDraft', () {
    test('choosing a baby starts afresh with its given name and its own records ticked', () {
      final items = [
        item('i1', [babyA]),
        item('i2', [babyB]),
      ];
      final d = BirthDraft(dob: DateTime(2020, 5)).withBlood(null).choose(baby(babyA, 1, name: 'Test Baby'), items);
      expect((d.babyId, d.name, d.sex, d.bloodUnsure), (babyA, 'Test Baby', null, false));
      expect(d.keep, {const PregnancyItemId.value('i1')});
      expect(d.dob, DateTime(2020, 5), reason: 'the date of birth stays');
    });

    test('ticks toggle, and sets compare by value', () {
      final d = BirthDraft(keep: {const PregnancyItemId.value('i1')});
      final off = d.toggleKeep(const PregnancyItemId.value('i1'));
      expect(off.keep, isEmpty);
      expect(off.toggleKeep(const PregnancyItemId.value('i1')), d);
    });

    test('valid once a baby is chosen with a name, sex and date of birth', () {
      final now = DateTime(2020, 6);
      var d = BirthDraft(dob: DateTime(2020, 5));
      expect(d.valid(now), isFalse);
      d = d.choose(baby(babyA, 1), const []).withName('Test Baby').withSex(Sex.female);
      expect(d.valid(now), isTrue);
      expect(d.details()?.bloodType, isNull);
      expect(d.withBlood(BloodType.oPositive).details()?.bloodType, BloodType.oPositive);
    });

    test('with one baby followed the notifier chooses it by itself', () async {
      final onlyItems = [
        item('i1', [babyA]),
      ];
      final c = ProviderContainer(
        retry: noProviderRetry,
        overrides: [
          pregnanciesOfProvider(mother).overrideWith(
            (ref) => Stream.value([
              Pregnancy(
                id: pregId,
                motherId: mother,
                dueDate: DateTime(2020, 9),
                createdAt: DateTime(2020),
              ),
            ]),
          ),
          pregnancyBabiesProvider(pregId).overrideWith((ref) => Stream.value([baby(babyA, 1, name: 'Test Baby')])),
          pregnancyItemsProvider((id: pregId, mother: mother)).overrideWith((ref) => Stream.value(onlyItems)),
        ],
      );
      addTearDown(c.dispose);
      final key = (form: Object(), mother: mother);
      final sub = c.listen(birthDraftProvider(key), (_, __) {});
      expect(sub.read().babyId, isNull);
      await pumpEventQueue();
      expect((sub.read().babyId, sub.read().name), (babyA, 'Test Baby'));
      expect(sub.read().keep, {const PregnancyItemId.value('i1')});

      // A later emission never overrides a baby already chosen.
      c.read(birthDraftProvider(key).notifier).setName('Typed');
      await pumpEventQueue();
      expect(sub.read().name, 'Typed');
    });
  });

  group('PregnancyItemDraft', () {
    final day = DateTime(2020, 4);

    test('me and babies exclude each other', () {
      var d = PregnancyItemDraft(date: day, babies: {babyA});
      d = d.toggleMe();
      expect(d.me, isTrue);
      expect(d.babies, isEmpty);
      d = d.toggleBaby(babyB);
      expect(d.me, isFalse);
      expect(d.babies, {babyB});
    });

    test('all babies toggles every one on, then off', () {
      final d = PregnancyItemDraft(date: day).toggleAll([babyA, babyB]);
      expect(d.babies, {babyA, babyB});
      expect(d.toggleAll([babyA, babyB]).babies, isEmpty);
    });

    test('measurements are for one baby at a time; otherwise the kind falls back to a scan', () {
      final one = PregnancyItemDraft(date: day, babies: {babyA}).withKind(ItemKind.measure);
      expect(one.effectiveKind, ItemKind.measure);
      expect(one.toggleBaby(babyB).effectiveKind, ItemKind.scan);
      expect(one.toggleMe().effectiveKind, ItemKind.scan);
    });

    test('the notifier opens with the babies the form was given', () {
      final c = ProviderContainer(retry: noProviderRetry);
      addTearDown(c.dispose);
      final key = (form: Object(), babyIds: const [babyA]);
      expect(c.read(pregnancyItemDraftProvider(key)).babies, {babyA});
      expect(() => c.read(pregnancyItemDraftProvider(key)).babies.add(babyB), throwsUnsupportedError);
    });
  });

  test('the visit sheet opens on the stored day and keeps the day picked', () {
    final c = ProviderContainer(retry: noProviderRetry);
    addTearDown(c.dispose);
    final key = (form: Object(), initial: DateTime(2020, 2));
    final sub = c.listen(nextVisitDayProvider(key), (_, __) {});
    expect(sub.read(), DateTime(2020, 2));
    c.read(nextVisitDayProvider(key).notifier).day = DateTime(2020, 3);
    expect(sub.read(), DateTime(2020, 3));
  });
}
