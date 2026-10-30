import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:self_report/self_report.dart';

void main() {
  late AppDatabase db;
  late DriftCheckInsDataSource ds;
  const profile = HealthProfileId.value('hp-1');

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    ds = DriftCheckInsDataSource(db, () => profile);
  });
  tearDown(() => db.close());

  CheckIn entry(String id) => CheckIn(
        id: CheckInId.value(id),
        healthProfileId: profile,
        recordedAt: DateTime.utc(2026, 7, 24, 9),
        painLevel: PainLevel.none,
        painSites: const {},
        symptoms: const {},
        vitals: const Vitals(systolic: 118, diastolic: 76),
      );

  test('deletes only the chosen check-in of the active profile', () async {
    final keep = entry('chk-keep');
    final drop = entry('chk-drop');
    await ds.put(keep.id, keep);
    await ds.put(drop.id, drop);

    await DeleteCheckInUseCase(dao: ds)(drop.id);

    expect(await ds.find(drop.id), isNull);
    expect((await ds.findAll()).map((c) => c.id), [keep.id]);
  });
}
