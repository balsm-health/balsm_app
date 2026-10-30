import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:self_report/self_report.dart';

void main() {
  CheckIn entry({PainLevel pain = PainLevel.none, Set<PainSite> sites = const {}}) => CheckIn(
        id: const CheckInId.value('chk-1'),
        healthProfileId: const HealthProfileId.value('hp-1'),
        recordedAt: DateTime.utc(2026, 7, 24, 9),
        painLevel: pain,
        painSites: sites,
        symptoms: const {},
        vitals: const Vitals(systolic: 118, diastolic: 76),
      );

  test('a blood-pressure-only log says nothing about pain', () {
    expect(entry().reportsPain, isFalse);
  });

  test('a pain score reports pain', () {
    expect(entry(pain: const PainLevel(4)).reportsPain, isTrue);
  });

  test('marked sites report pain even at score zero', () {
    expect(entry(sites: {PainSite(Muscle.chest)}).reportsPain, isTrue);
  });
}
