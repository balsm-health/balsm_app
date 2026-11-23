import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:self_report/self_report.dart';

/// Hostile input: every validator must answer true/false for any number it is
/// handed, never throw, and never accept something outside its documented range.
void main() {
  final rng = Random(42);

  const wild = <int>[
    0, 1, -1, -999, 999, 1000, 65535, 2147483647, -2147483648, 4294967296, 9007199254740991, //
  ];

  group('integer validators never throw and never leak out of range', () {
    test('fixed extremes', () {
      for (final n in wild) {
        expect(() => VitalLimits.heartRateOk(n), returnsNormally);
        expect(() => VitalLimits.spo2Ok(n), returnsNormally);
        expect(() => VitalLimits.glucoseOk(n), returnsNormally);
        expect(() => VitalLimits.bloodPressureOk(n, n), returnsNormally);
        expect(VitalLimits.heartRateOk(n), n >= 30 && n <= 220, reason: '$n');
        expect(VitalLimits.spo2Ok(n), n >= 50 && n <= 100, reason: '$n');
        expect(VitalLimits.glucoseOk(n), n >= 20 && n <= 600, reason: '$n');
      }
    });

    test('20000 random values agree with the documented ranges', () {
      for (var i = 0; i < 20000; i++) {
        final n = rng.nextInt(4000) - 1000;
        final m = rng.nextInt(4000) - 1000;
        expect(VitalLimits.heartRateOk(n), n >= 30 && n <= 220, reason: 'hr $n');
        expect(VitalLimits.spo2Ok(n), n >= 50 && n <= 100, reason: 'spo2 $n');
        expect(VitalLimits.glucoseOk(n), n >= 20 && n <= 600, reason: 'glu $n');
        final bp = n >= 60 && n <= 260 && m >= 30 && m <= 160 && n > m;
        expect(VitalLimits.bloodPressureOk(n, m), bp, reason: 'bp $n/$m');
      }
    });

    test('null is never plausible', () {
      expect(VitalLimits.heartRateOk(null), isFalse);
      expect(VitalLimits.spo2Ok(null), isFalse);
      expect(VitalLimits.glucoseOk(null), isFalse);
      expect(VitalLimits.weightKgOk(null), isFalse);
      expect(VitalLimits.bloodPressureOk(null, null), isFalse);
      expect(VitalLimits.bloodPressureOk(120, null), isFalse);
    });
  });

  group('weight handles every double, including the unrepresentable', () {
    test('NaN, infinities, negatives, subnormals', () {
      for (final w in [double.nan, double.infinity, double.negativeInfinity, -0.0, -1.0, 5e-324, 1e308, 0.4999, 500.0001]) {
        expect(() => VitalLimits.weightKgOk(w), returnsNormally);
        expect(VitalLimits.weightKgOk(w), isFalse, reason: '$w');
      }
      for (final w in [0.5, 3.4, 72.5, 500.0]) {
        expect(VitalLimits.weightKgOk(w), isTrue, reason: '$w');
      }
    });
  });

  group('elevated cut-offs are monotonic', () {
    test('a higher reading is never "less elevated" than a lower one', () {
      for (final ctx in GlucoseContext.values) {
        var seen = false;
        for (var g = 0; g <= 700; g++) {
          final e = VitalLimits.glucoseElevated(g, ctx);
          if (seen) expect(e, isTrue, reason: '$ctx $g regressed after a flagged value');
          seen = seen || e;
        }
        expect(seen, isTrue, reason: '$ctx is never flagged');
      }
    });

    test('blood pressure flag rises with either number', () {
      for (var i = 0; i < 5000; i++) {
        final s = 60 + rng.nextInt(200);
        final d = 30 + rng.nextInt(130);
        if (VitalLimits.bloodPressureElevated(s, d)) {
          expect(VitalLimits.bloodPressureElevated(s + 1, d), isTrue);
          expect(VitalLimits.bloodPressureElevated(s, d + 1), isTrue);
        }
      }
    });
  });
}
