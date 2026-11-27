import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Synthetic actors only.
  final family = ProvenanceActor.other(ProvenanceActorKind.family, displayName: 'Member A');
  final doctor = ProvenanceActor.other(ProvenanceActorKind.doctor, careProviderId: 'cp-1');

  ProvenanceEvent ev(String id, ProvenanceActor actor, ProvenanceAction action, DateTime at) =>
      ProvenanceEvent(id: id, actor: actor, action: action, at: at);

  group('ProvenanceActor', () {
    test('someone else needs a name or a care-team reference', () {
      expect(() => ProvenanceActor.other(ProvenanceActorKind.clinic), throwsArgumentError);
      expect(() => ProvenanceActor.other(ProvenanceActorKind.family, displayName: '  '), throwsArgumentError);
      expect(() => ProvenanceActor.other(ProvenanceActorKind.self, displayName: 'X'), throwsArgumentError);
    });

    test('trims the name and drops a blank reference', () {
      final a = ProvenanceActor.other(ProvenanceActorKind.family, displayName: ' Member A ', careProviderId: ' ');
      expect(a.displayName, 'Member A');
      expect(a.careProviderId, isNull);
      expect(a, family);
      expect(a.isSelf, isFalse);
      expect(ProvenanceActor.self.isSelf, isTrue);
    });

    test('stored codes round-trip and unknown ones are refused', () {
      for (final k in ProvenanceActorKind.values) {
        expect(ProvenanceActorKind.fromWire(k.wire), k);
      }
      for (final a in ProvenanceAction.values) {
        expect(ProvenanceAction.fromWire(a.wire), a);
      }
      expect(() => ProvenanceActorKind.fromWire('nurse'), throwsFormatException);
      expect(() => ProvenanceAction.fromWire('deleted'), throwsFormatException);
    });
  });

  group('EntryHistory', () {
    test("the patient's own entry has no attribution and stays empty when edited", () {
      expect(EntryHistory.none.isAttributed, isFalse);
      expect(EntryHistory.none.stampSelfEdit(DateTime.utc(2026, 1, 2)), same(EntryHistory.none));
    });

    test('attribution is the latest event by someone else', () {
      final h = EntryHistory([
        ev('1', doctor, ProvenanceAction.added, DateTime.utc(2026)),
        ev('2', family, ProvenanceAction.edited, DateTime.utc(2026, 1, 3)),
        ev('3', ProvenanceActor.self, ProvenanceAction.edited, DateTime.utc(2026, 1, 4)),
      ]);
      expect(h.attribution!.id, '2');
      expect(h.wasEdited, isTrue);
    });

    test('a self edit is appended to an attributed entry, never replacing anything', () {
      final added = ev('1', family, ProvenanceAction.added, DateTime.utc(2026));
      final h = EntryHistory([added]);
      final at = DateTime.utc(2026, 2, 1, 9);
      final next = h.stampSelfEdit(at);
      expect(next.events, hasLength(2));
      expect(next.events.first, added);
      expect(next.events.last.actor, ProvenanceActor.self);
      expect(next.events.last.action, ProvenanceAction.edited);
      expect(next.events.last.at, at);
      expect(next.attribution, added, reason: 'still shown as coming from the family member');
      expect(h.events, hasLength(1), reason: 'the original history is unchanged');
      expect(() => next.events.add(added), throwsUnsupportedError);
    });

    test('newestFirst orders by time, later-appended first on a tie', () {
      final t = DateTime.utc(2026);
      final h = EntryHistory([
        ev('a', doctor, ProvenanceAction.shared, t),
        ev('b', family, ProvenanceAction.edited, DateTime.utc(2026, 3)),
        ev('c', ProvenanceActor.self, ProvenanceAction.edited, t),
      ]);
      expect(h.newestFirst.map((e) => e.id), ['b', 'c', 'a']);
    });
  });
}
