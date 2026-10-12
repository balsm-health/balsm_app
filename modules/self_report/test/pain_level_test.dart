import 'package:flutter_test/flutter_test.dart';
import 'package:self_report/self_report.dart';

/// NRS-11 banding. Every boundary is inclusive of the lower band, so 3 is mild
/// and 4 is moderate — a shift here changes what a clinician reads.
void main() {
  PainBand band(int n) => PainLevel(n).band;

  test('0 is its own band, not mild', () {
    expect(band(0), PainBand.none);
  });

  test('1 through 3 are mild', () {
    for (final n in [1, 2, 3]) {
      expect(band(n), PainBand.mild, reason: 'score $n');
    }
  });

  test('4 through 6 are moderate', () {
    for (final n in [4, 5, 6]) {
      expect(band(n), PainBand.moderate, reason: 'score $n');
    }
  });

  test('7 through 9 are severe', () {
    for (final n in [7, 8, 9]) {
      expect(band(n), PainBand.severe, reason: 'score $n');
    }
  });

  test('10 is worst, alone', () {
    expect(band(10), PainBand.worst);
    expect(band(9), isNot(PainBand.worst));
  });

  test('every score on the scale has a band', () {
    for (var n = 0; n <= 10; n++) {
      expect(() => band(n), returnsNormally, reason: 'score $n');
    }
  });

  test('the scale itself is bounded', () {
    expect(() => PainLevel(11), throwsA(isA<AssertionError>()));
    expect(() => PainLevel(-1), throwsA(isA<AssertionError>()));
  });
}
