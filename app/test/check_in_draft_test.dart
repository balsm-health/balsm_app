import 'package:app/balsm_app/screens/check_in_draft.dart';
import 'package:app/balsm_app/screens/metric_drafts.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medications/medications.dart';
import 'package:self_report/self_report.dart';

/// The full check-in's draft as plain transitions. Synthetic readings only.
void main() {
  const bp = MetricLogCapture(summary: '120/80', vitals: Vitals(systolic: 120, diastolic: 80));
  const glucose = MetricLogCapture(summary: '95', vitals: Vitals(glucoseFasting: 95));
  const steps = ['mood', 'bp', 'glucose', kMedsCheckInStepId];

  test('a step opens Next once its capture is complete; meds never block', () {
    final d = CheckInDraft().capture('bp', bp, valid: false);
    expect(d.canAdvance('bp'), isFalse);
    expect(d.capture('bp', bp, valid: true).canAdvance('bp'), isTrue);
    expect(d.canAdvance(kMedsCheckInStepId), isTrue);
  });

  test('skipping discards what was typed, keeps Next open, and ignores later reports', () {
    final d = CheckInDraft().capture('bp', bp, valid: true).toggleSkip('bp');
    expect(d.captures, isEmpty);
    expect(d.canAdvance('bp'), isTrue);
    expect(d.capture('bp', bp, valid: true).captures, isEmpty);
    expect(d.toggleSkip('bp').skipped, isEmpty);
  });

  test('a medication toggles taken, and Skip marks it skipped', () {
    final taken = CheckInDraft().toggleTaken('med-1');
    expect(taken.medMarks, {'med-1': DoseOutcome.taken});
    expect(taken.toggleTaken('med-1').medMarks, isEmpty);
    expect(taken.markSkipped('med-1').medMarks, {'med-1': DoseOutcome.skipped});
    expect(taken.markSkipped('med-1').toggleTaken('med-1').medMarks, {'med-1': DoseOutcome.taken});
  });

  test('any capture or mark is input that leaving would throw away', () {
    expect(CheckInDraft().hasInput, isFalse);
    expect(CheckInDraft().capture('bp', bp, valid: false).hasInput, isTrue);
    expect(CheckInDraft().toggleTaken('med-1').hasInput, isTrue);
  });

  test('the steps merge into one check-in', () {
    final d = CheckInDraft()
        .capture('mood', const MetricLogCapture(mood: Mood.ok, note: ' first '), valid: true)
        .capture('bp', bp, valid: true)
        .capture('glucose', glucose, valid: true);
    final at = DateTime(2026, 7, 24, 9);
    final ci = d.toCheckIn(
      id: const CheckInId.value('chk-1'),
      profile: const HealthProfileId.value('hp-1'),
      steps: steps,
      now: at,
    );
    expect(ci.mood, Mood.ok);
    expect(ci.vitals, const Vitals(systolic: 120, diastolic: 80, glucoseFasting: 95));
    expect(ci.note, 'first');
    expect(ci.recordedAt, at);
  });

  test('an edited capture under the same step is a different draft', () {
    final a = CheckInDraft().capture('bp', bp, valid: true);
    expect(a, CheckInDraft().capture('bp', bp, valid: true));
    const edited = MetricLogCapture(summary: '120/84', vitals: Vitals(systolic: 120, diastolic: 84));
    expect(a.capture('bp', edited, valid: true), isNot(a));
  });

  test('two check-ins never share a draft', () {
    final c = ProviderContainer(retry: noProviderRetry);
    addTearDown(c.dispose);
    final one = Object();
    final two = Object();
    c
      ..listen(checkInDraftProvider(one), (_, __) {})
      ..listen(checkInDraftProvider(two), (_, __) {});
    c.read(checkInDraftProvider(one).notifier)
      ..capture('bp', bp, valid: true)
      ..toggleTaken('med-1');
    expect(c.read(checkInDraftProvider(one)).hasInput, isTrue);
    expect(c.read(checkInDraftProvider(two)).hasInput, isFalse);
  });
}
