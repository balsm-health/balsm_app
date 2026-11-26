import 'package:core/core.dart' show noProviderRetry;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show TimeOfDay;
import 'package:medications/src/domain/aggregates/medication.dart';
import 'package:medications/src/presentation/providers/medication_draft.dart';

void main() {
  late ProviderContainer c;
  final form = Object();

  setUp(() {
    c = ProviderContainer(retry: noProviderRetry);
    addTearDown(c.dispose);
    c.listen(medicationDraftProvider(form), (_, __) {});
  });

  MedicationDraft draft() => c.read(medicationDraftProvider(form));
  MedicationDraftNotifier edit() => c.read(medicationDraftProvider(form).notifier);

  test('starts daily with one 08:00 reminder and every weekday', () {
    expect(draft().scheduleType, ScheduleType.daily);
    expect(draft().sortedTimes, ['08:00']);
    expect(draft().days, {1, 2, 3, 4, 5, 6, 7});
    expect(draft().endDate, isNull);
  });

  test('times are kept in order added and saved earliest first', () {
    edit()
      ..addTime(const TimeOfDay(hour: 6, minute: 5))
      ..replaceTime(0, const TimeOfDay(hour: 21, minute: 30));
    expect(draft().times.first, const TimeOfDay(hour: 21, minute: 30));
    expect(draft().sortedTimes, ['06:05', '21:30']);
  });

  test('the last reminder cannot be removed', () {
    edit().removeTime(0);
    expect(draft().times, hasLength(1));
    edit()
      ..addTime(const TimeOfDay(hour: 9, minute: 0))
      ..removeTime(0);
    expect(draft().sortedTimes, ['09:00']);
  });

  test('a weekly schedule with no day selected is not valid', () {
    edit().setSchedule(ScheduleType.weekly);
    for (var d = 1; d <= 7; d++) {
      edit().toggleDay(d);
    }
    expect(draft().days, isEmpty);
    expect(draft().daysValid, isFalse);
    edit().toggleDay(3);
    expect(draft().daysValid, isTrue);
  });

  test('an empty name is flagged and cleared once typed', () {
    expect(edit().validate('  '), isFalse);
    expect(draft().nameMissing, isTrue);
    expect(edit().validate('x'), isTrue);
    expect(draft().nameMissing, isFalse);
  });

  test('the end date can be set and cleared', () {
    edit().setEnd(DateTime(2030));
    expect(draft().endDate, DateTime(2030));
    edit().setEnd(null);
    expect(draft().endDate, isNull);
  });

  test('collections cannot be changed from outside', () {
    expect(() => draft().times.add(const TimeOfDay(hour: 1, minute: 0)), throwsUnsupportedError);
    expect(() => draft().days.add(9), throwsUnsupportedError);
  });

  test('equality covers every field, collections by value', () {
    final start = DateTime(2030);
    final a = MedicationDraft(startDate: start);
    expect(a, MedicationDraft(startDate: start));
    expect(a.hashCode, MedicationDraft(startDate: start).hashCode);
    expect(a == a.addTime(const TimeOfDay(hour: 1, minute: 0)), isFalse);
    expect(a == a.toggleDay(1), isFalse);
    expect(a == a.withSchedule(ScheduleType.weekly), isFalse);
    expect(a == a.withEnd(start), isFalse);
    expect(a == a.withControlled(controlled: true), isFalse);
    expect(a == a.validated(''), isFalse);
    expect(a == a.withStart(DateTime(2031)), isFalse);
  });

  test('two forms keep separate drafts, and a closed form drops its draft', () async {
    final other = Object();
    final sub = c.listen(medicationDraftProvider(other), (_, __) {});
    c.read(medicationDraftProvider(other).notifier).setControlled(controlled: true);
    expect(draft().isControlled, isFalse);

    sub.close();
    await c.pump();
    expect(c.read(medicationDraftProvider(other)).isControlled, isFalse, reason: 'reopened from scratch');
  });
}
