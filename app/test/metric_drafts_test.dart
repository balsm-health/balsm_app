import 'package:app/balsm_app/screens/metric_drafts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:self_report/self_report.dart';

/// The vitals keypad rules as plain state transitions: what each press does,
/// with no widget involved. The widget tests (medical_inputs_test) cover the
/// same pads through the screen.
void main() {
  BpDraft typeBp(String digits) => digits.split('').fold(const BpDraft(), (d, k) => d.key(k));

  group('blood pressure', () {
    test('three systolic digits move on to diastolic by themselves', () {
      final d = typeBp('120');
      expect((d.sys, d.onSys), ('120', false));
      expect(typeBp('12080').dia, '80');
    });

    test('digits stop at three per field', () {
      expect(typeBp('1201234').dia, '123');
    });

    test('back steps through diastolic, then returns to systolic', () {
      var d = typeBp('12080');
      d = d.back();
      expect(d.dia, '8');
      d = d.back().back();
      expect((d.dia, d.onSys), ('', true), reason: 'an empty diastolic hands the cursor back');
      expect(d.sys, '120');
    });

    test('validity follows VitalLimits (systolic above diastolic, in range)', () {
      expect(typeBp('12080').valid, isTrue);
      expect(typeBp('120120').valid, isFalse);
      expect(typeBp('120').valid, isFalse);
      expect(typeBp('12080').vitals, const Vitals(systolic: 120, diastolic: 80));
      expect(typeBp('120120').vitals, Vitals.empty);
    });

    test('an edit opens on the stored reading, cursor on systolic only when diastolic is empty', () {
      final d = BpDraft.from(const Vitals(systolic: 130, diastolic: 85));
      expect((d.sys, d.dia, d.onSys), ('130', '85', false));
      expect(BpDraft.from(null).onSys, isTrue);
    });
  });

  group('glucose', () {
    test('three digits at most; context decides which column the value lands in', () {
      var d = const GlucoseDraft();
      for (final k in '1234'.split('')) {
        d = d.key(k);
      }
      expect(d.digits, '123');
      expect(d.withContext(GlucoseContext.postMeal).vitals, const Vitals(glucosePostMeal: 123));
      expect(d.withContext(GlucoseContext.random).vitals, const Vitals(glucoseRandom: 123));
      expect(d.vitals, const Vitals(glucoseFasting: 123));
    });

    test('an edit reopens on the stored context', () {
      expect(GlucoseDraft.from(const Vitals(glucosePostMeal: 150)).context, GlucoseContext.postMeal);
      expect(GlucoseDraft.from(const Vitals(glucoseRandom: 110)).context, GlucoseContext.random);
      expect(GlucoseDraft.from(null).context, GlucoseContext.fasting);
    });

    test('out-of-range values give an empty reading', () {
      expect(const GlucoseDraft(digits: '5').vitals, Vitals.empty);
      expect(const GlucoseDraft(digits: '999').vitals, Vitals.empty);
    });
  });

  group('weight', () {
    WeightDraft type(String keys) => keys.split('').fold(const WeightDraft(), (d, k) => k == '.' ? d.dot() : d.key(k));

    test('whole kilos then one decimal', () {
      expect(type('72.5').display, '72.5');
      expect(type('72.57').display, '72.5', reason: 'only one decimal');
      expect(type('7234').display, '723', reason: 'three whole digits at most');
    });

    test('the dot needs a digit before it', () {
      expect(type('.').hasDot, isFalse);
      expect(type('3.').display, '3.0');
    });

    test('back removes the decimal, then the dot, then whole digits', () {
      var d = type('72.5');
      d = d.back();
      expect((d.hasDot, d.decimals), (true, ''));
      d = d.back();
      expect(d.hasDot, isFalse);
      expect(d.back().kg, '7');
    });

    test('a newborn saves; zero does not', () {
      expect(type('3.4').vitals, const Vitals(weightKg: 3.4));
      expect(type('0').vitals, Vitals.empty);
    });

    test('an edit reopens on the stored weight', () {
      final d = WeightDraft.from(const Vitals(weightKg: 72.5));
      expect((d.kg, d.decimals, d.hasDot), ('72', '5', true));
      expect(WeightDraft.from(const Vitals(weightKg: 80)).hasDot, isFalse);
    });
  });

  group('SpO2', () {
    Spo2Draft type(String keys) => keys.split('').fold(const Spo2Draft(), (d, k) => d.key(k));

    test('two digits, and a third only completes 100', () {
      expect(type('98').digits, '98');
      expect(type('999').digits, '99');
      expect(type('100').digits, '100');
      expect(type('101').digits, '10');
    });

    test('validity is 50-100', () {
      expect(type('49').valid, isFalse);
      expect(type('50').valid, isTrue);
      expect(type('100').valid, isTrue);
    });
  });

  group('pulse', () {
    test('typing is capped at three digits and validated 30-220', () {
      var d = const PulseDraft();
      for (final k in '2201'.split('')) {
        d = d.key(k);
      }
      expect(d.digits, '220');
      expect(d.valid, isTrue);
      expect(const PulseDraft(digits: '29').valid, isFalse);
    });

    test('counting beats: first tap starts the clock, the rate is count x 4', () {
      var d = const PulseDraft().startCounting();
      expect(d.valid, isFalse, reason: 'not valid while counting');
      d = d.beat();
      expect((d.beats, d.left), (1, kPulseCountSeconds));
      for (var i = 0; i < 17; i++) {
        d = d.beat();
      }
      expect(d.beats, 18);
      for (var i = 0; i < kPulseCountSeconds; i++) {
        d = d.tick();
      }
      expect((d.counting, d.left, d.digits), (false, null, '72'));
      expect(d.valid, isTrue);
    });

    test('typing instead leaves counting without a value', () {
      expect(const PulseDraft().startCounting().beat().typeInstead().counting, isFalse);
    });
  });

  group('providers', () {
    test('two forms never share a draft; each opens on its own stored reading', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final a = (form: Object(), initial: const Vitals(systolic: 120, diastolic: 80));
      final b = (form: Object(), initial: null as Vitals?);
      c
        ..listen(bpDraftProvider(a), (_, __) {})
        ..listen(bpDraftProvider(b), (_, __) {});
      c.read(bpDraftProvider(b).notifier).key('9');
      expect(c.read(bpDraftProvider(a)).sys, '120');
      expect(c.read(bpDraftProvider(b)).sys, '9');
    });
  });
}
