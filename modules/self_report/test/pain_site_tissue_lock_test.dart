import 'package:flutter_test/flutter_test.dart';
import 'package:self_report/self_report.dart';

/// One tissue per check-in (approved behaviour rule): [canToggleSite] /
/// [lockedBodyTissue] are the single shared helper the body map's tap path
/// and the check-in screens' onToggle handlers both lean on — covered here
/// in isolation from any widget.
void main() {
  const chestMuscle = PainSite(Muscle.chest);
  const neckMuscle = PainSite(Muscle.neck);
  const chestNerve = PainSite(Nerve.chest);

  group('lockedBodyTissue', () {
    test('null for an empty selection — any layer may still be chosen', () {
      expect(lockedBodyTissue(const {}), isNull);
    });

    test('the tissue of the only site', () {
      expect(lockedBodyTissue({chestMuscle}), BodyTissue.muscle);
    });

    test('a legacy mixed selection defers to the first site, no crash', () {
      final mixed = <PainSite>{chestMuscle, chestNerve};
      expect(() => lockedBodyTissue(mixed), returnsNormally);
      expect(lockedBodyTissue(mixed), mixed.first.tissue);
    });
  });

  group('canToggleSite', () {
    test('allows any site into an empty selection', () {
      expect(canToggleSite(const {}, chestMuscle), isTrue);
      expect(canToggleSite(const {}, chestNerve), isTrue);
    });

    test('allows a same-tissue addition', () {
      expect(canToggleSite({chestMuscle}, neckMuscle), isTrue);
    });

    test('rejects a different-tissue addition', () {
      expect(canToggleSite({chestMuscle}, chestNerve), isFalse);
    });

    test('removing an already-marked site is always allowed, even a legacy mix', () {
      expect(canToggleSite({chestMuscle}, chestMuscle), isTrue);
      final mixed = <PainSite>{chestMuscle, chestNerve};
      expect(canToggleSite(mixed, chestMuscle), isTrue);
      expect(canToggleSite(mixed, chestNerve), isTrue);
    });
  });
}
