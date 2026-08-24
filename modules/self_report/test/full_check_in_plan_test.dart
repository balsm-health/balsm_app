import 'package:flutter_test/flutter_test.dart';
import 'package:self_report/self_report.dart';

void main() {
  group('resolveTrackedMetrics', () {
    test('null or empty falls back to catalog defaults', () {
      expect(resolveTrackedMetrics(null), CheckInMetric.defaultFullCheckup);
      expect(resolveTrackedMetrics(const []), CheckInMetric.defaultFullCheckup);
    });

    test('drops unknown ids and keeps stored order', () {
      expect(
        resolveTrackedMetrics(const ['glucose', 'nope', 'mood']),
        [CheckInMetric.glucose, CheckInMetric.mood],
      );
    });

    test('all-unknown falls back to defaults', () {
      expect(resolveTrackedMetrics(const ['nope']), CheckInMetric.defaultFullCheckup);
    });
  });

  group('fullCheckInSteps', () {
    test('defaults match today\'s wizard without meds', () {
      expect(
        fullCheckInSteps(tracked: CheckInMetric.defaultFullCheckup, hasMeds: false),
        ['mood', 'bp', 'glucose', 'pain', 'symptoms'],
      );
    });

    test('inserts meds before the first journal metric', () {
      expect(
        fullCheckInSteps(tracked: CheckInMetric.defaultFullCheckup, hasMeds: true),
        ['mood', 'bp', 'glucose', 'meds', 'pain', 'symptoms'],
      );
    });

    test('skips untracked metrics and metrics without a wizard page', () {
      expect(
        fullCheckInSteps(
          tracked: const [CheckInMetric.mood, CheckInMetric.heartRate, CheckInMetric.glucose],
          hasMeds: false,
        ),
        ['mood', 'glucose'],
      );
    });

    test('includes a tracked wizard-ready vital such as weight', () {
      expect(
        fullCheckInSteps(
          tracked: const [CheckInMetric.mood, CheckInMetric.weight, CheckInMetric.glucose],
          hasMeds: false,
        ),
        ['mood', 'weight', 'glucose'],
      );
    });

    test('meds go last when journal is untracked', () {
      expect(
        fullCheckInSteps(
          tracked: const [CheckInMetric.mood, CheckInMetric.bloodPressure],
          hasMeds: true,
        ),
        ['mood', 'bp', 'meds'],
      );
    });
  });
}
