import 'package:app/balsm_app/screens/metric_drafts.dart';
import 'package:core/core.dart' show noProviderRetry;
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
      final c = ProviderContainer(retry: noProviderRetry);
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

  // Synthetic sites and symptoms only; nothing here is patient data.
  const shoulder = PainSite(Joint.l_shoulder);
  const otherShoulder = PainSite(Joint.r_shoulder);
  const eye = PainSite(Muscle.l_eye);

  group('mood', () {
    test('opens on the stored mood, or on none', () {
      expect(MoodDraft.from(const MetricLogCapture(mood: Mood.low)).score, 2);
      expect(MoodDraft.from(null).valid, isFalse);
    });

    test('a pick is valid and becomes the mood', () {
      final d = const MoodDraft().pick(4);
      expect((d.valid, d.mood), (true, Mood.good));
    });

    test('equal by value; a different pick is a different draft', () {
      expect(const MoodDraft(3), const MoodDraft().pick(3));
      expect(const MoodDraft(3), isNot(const MoodDraft().pick(4)));
    });
  });

  group('pain', () {
    test('a level or a site alone makes it valid', () {
      expect(PainDraft().valid, isFalse);
      expect(PainDraft().withLevel(3).valid, isTrue);
      expect(PainDraft().toggleSite(shoulder).valid, isTrue);
    });

    test('a site toggles on and off, and the set cannot be changed in place', () {
      final on = PainDraft().toggleSite(shoulder);
      expect(on.sites, {shoulder});
      expect(on.toggleSite(shoulder).sites, isEmpty);
      expect(() => on.sites.add(otherShoulder), throwsUnsupportedError);
    });

    test('a site on another tissue is refused', () {
      final joint = PainDraft().toggleSite(shoulder);
      expect(joint.toggleSite(eye), same(joint));
    });

    test('equal by value; a toggled site is a different draft', () {
      expect(PainDraft(level: 2, sites: {shoulder}), PainDraft(level: 2, sites: {shoulder}));
      expect(
        PainDraft(level: 2, sites: {shoulder}),
        isNot(PainDraft(level: 2, sites: {shoulder}).toggleSite(otherShoulder)),
      );
    });

    test('opens on the stored level and sites', () {
      final d = PainDraft.from(MetricLogCapture(painLevel: const PainLevel(6), painSites: {shoulder}));
      expect(d.level, 6);
      expect(d.sites, {shoulder});
    });
  });

  group('symptoms', () {
    test('single-select swaps the symptom; multi-select adds it', () {
      final one = SymptomsDraft().select(SymptomId.headache, multi: false).select(SymptomId.nausea, multi: false);
      expect(one.symptoms, {SymptomId.nausea});
      final many = SymptomsDraft().select(SymptomId.headache, multi: true).select(SymptomId.nausea, multi: true);
      expect(many.symptoms, {SymptomId.headache, SymptomId.nausea});
    });

    test('"none" clears every symptom and site, and a symptom clears "none"', () {
      final none = SymptomsDraft(symptoms: {SymptomId.swelling}, sites: {shoulder}).toggleNone();
      expect(none.none, isTrue);
      expect(none.symptoms, isEmpty);
      expect(none.sites, isEmpty);
      expect(none.valid, isTrue);
      expect(none.select(SymptomId.headache, multi: true).none, isFalse);
    });

    test('sites are kept only while a located symptom is picked', () {
      final located = SymptomsDraft().select(SymptomId.swelling, multi: true).toggleSite(shoulder);
      expect(located.showMap, isTrue);
      expect(located.sites, {shoulder});
      expect(located.select(SymptomId.swelling, multi: true).sites, isEmpty);
    });

    test('equal by value; a different selection is a different draft', () {
      expect(SymptomsDraft(symptoms: {SymptomId.headache}), SymptomsDraft(symptoms: {SymptomId.headache}));
      expect(SymptomsDraft(symptoms: {SymptomId.headache}), isNot(SymptomsDraft(symptoms: {SymptomId.nausea})));
    });
  });

  group('one symptom', () {
    test('opens on the stored detail for that symptom', () {
      const detail = SymptomDetail(blood: true);
      final d = OneSymptomDraft.from(
        MetricLogCapture(symptomDetails: {SymptomId.urine: detail}, painSites: {shoulder}),
        SymptomId.urine,
      );
      expect(d.detail, detail);
      expect(d.sites, {shoulder});
    });

    test('an edited detail is a different draft', () {
      final d = OneSymptomDraft();
      expect(d.withDetail(const SymptomDetail(blood: true)), isNot(d));
      expect(d.withDetail(const SymptomDetail()), d);
    });
  });

  group('capture', () {
    test('equal only when every field is: the time and the details count', () {
      final at = DateTime(2026, 7, 24, 9);
      final a = MetricLogCapture(mood: Mood.ok, when: at);
      expect(a, MetricLogCapture(mood: Mood.ok, when: at));
      expect(a, isNot(MetricLogCapture(mood: Mood.ok, when: at.add(const Duration(minutes: 5)))));
      expect(
        MetricLogCapture(symptomDetails: {SymptomId.urine: const SymptomDetail()}),
        isNot(MetricLogCapture(symptomDetails: {SymptomId.urine: const SymptomDetail(blood: true)})),
      );
    });
  });

  group('capture-keyed providers', () {
    test('an edit opens on the stored entry; two forms never share', () {
      final c = ProviderContainer(retry: noProviderRetry);
      addTearDown(c.dispose);
      final CaptureDraftKey edit = (form: Object(), initial: const MetricLogCapture(mood: Mood.veryLow));
      final CaptureDraftKey fresh = (form: Object(), initial: null);
      c
        ..listen(moodDraftProvider(edit), (_, __) {})
        ..listen(moodDraftProvider(fresh), (_, __) {});
      c.read(moodDraftProvider(fresh).notifier).pick(5);
      expect(c.read(moodDraftProvider(edit)).score, 1);
      expect(c.read(moodDraftProvider(fresh)).score, 5);
    });

    test('each transition reaches the listener', () {
      final c = ProviderContainer(retry: noProviderRetry);
      addTearDown(c.dispose);
      final CaptureDraftKey key = (form: Object(), initial: null);
      final seen = <PainDraft>[];
      c.listen(painDraftProvider(key), (_, next) => seen.add(next));
      c.read(painDraftProvider(key).notifier)
        ..toggleSite(shoulder)
        ..setLevel(4)
        ..setLevel(4);
      // The repeated level equals the last draft, so it is filtered.
      final expected = [
        PainDraft(sites: {shoulder}),
        PainDraft(level: 4, sites: {shoulder}),
      ];
      expect(seen, expected);
    });

    test('the one-symptom draft opens on the stored detail and takes edits', () {
      final c = ProviderContainer(retry: noProviderRetry);
      addTearDown(c.dispose);
      final OneSymptomKey key = (
        form: Object(),
        initial: MetricLogCapture(symptomDetails: {SymptomId.urine: const SymptomDetail(urineMl: 100)}),
        symptom: SymptomId.urine,
      );
      c.listen(oneSymptomDraftProvider(key), (_, __) {});
      expect(c.read(oneSymptomDraftProvider(key)).detail.urineMl, 100);
      c.read(oneSymptomDraftProvider(key).notifier).setDetail(const SymptomDetail(blood: true));
      expect(c.read(oneSymptomDraftProvider(key)).detail.blood, isTrue);
    });
  });
}
