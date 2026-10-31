import 'package:app/balsm_app/screens/checkin_shared.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:self_report/self_report.dart';

/// Home's recent reports and the trends list show one row per date.
///
/// The readings are invented by the test; nothing here is real patient data.
void main() {
  CheckIn at(String id, DateTime when) => CheckIn(
        id: CheckInId.value(id),
        healthProfileId: const HealthProfileId.value('hp-1'),
        recordedAt: when,
        painLevel: PainLevel.none,
        painSites: const {},
        symptoms: const {},
        vitals: const Vitals(),
      );

  test('groups newest-first history by local day, each day oldest first', () {
    final history = [
      at('c', DateTime(2026, 7, 25, 9)),
      at('b', DateTime(2026, 7, 24, 20)),
      at('a', DateTime(2026, 7, 24, 8)),
    ];
    final days = groupCheckInsByDay(history);
    expect(days.map((d) => d.map((c) => c.id.value).toList()).toList(), [
      ['c'],
      ['a', 'b'],
    ]);
  });

  test('no history, no days', () => expect(groupCheckInsByDay(const []), isEmpty));
}
