import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prescriptions/prescriptions.dart';

void main() {
  late AppDatabase db;
  late DriftPrescriptionsDataSource ds;
  const user = UserId.value('u-1');

  Prescription sample(String id, {DateTime? until}) => Prescription(
        id: PrescriptionId.value(id),
        userId: user,
        clinician: 'Dr. Layla Hassan',
        specialty: 'Cardiology',
        reference: 'RX-4821-QQ',
        items: const [
          PrescribedItem(name: 'Metformin', dose: '500mg · twice daily'),
          PrescribedItem(name: 'Atorvastatin'),
        ],
        issuedAt: DateTime.utc(2026, 8, 1),
        validUntil: until,
        createdAt: DateTime.utc(2026, 8, 1),
      );

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    ds = DriftPrescriptionsDataSource(db, () => user);
  });
  tearDown(() => db.close());

  test('items round-trip through the json column', () async {
    final rx = sample('r1', until: DateTime.utc(2026, 12, 1));
    await ds.put(rx.id, rx);

    final got = await ds.find(rx.id);
    expect(got, isNotNull);
    expect(got!.items.length, 2);
    expect(got.items.first.name, 'Metformin');
    expect(got.items.first.dose, '500mg · twice daily');
    // A line with no dose keeps a null rather than an empty string.
    expect(got.items.last.dose, isNull);
    expect(got.reference, 'RX-4821-QQ');
    expect(got.validUntil?.toUtc(), DateTime.utc(2026, 12, 1));
  });

  test('an open-ended script stays active', () {
    expect(sample('r2').isActive(DateTime.utc(2030)), isTrue);
  });

  test('validity drives active/expired', () {
    final now = DateTime.utc(2026, 9, 1);
    expect(sample('a', until: DateTime.utc(2026, 12, 1)).isActive(now), isTrue);
    expect(sample('b', until: DateTime.utc(2026, 1, 1)).isActive(now), isFalse);
  });

  test('findAll is newest-first and user-scoped', () async {
    await ds.put(
        const PrescriptionId.value('old'),
        Prescription(
            id: const PrescriptionId.value('old'),
            userId: user,
            clinician: 'A',
            issuedAt: DateTime.utc(2026, 1, 1),
            createdAt: DateTime.utc(2026, 1, 1)));
    await ds.put(
        const PrescriptionId.value('new'),
        Prescription(
            id: const PrescriptionId.value('new'),
            userId: user,
            clinician: 'B',
            issuedAt: DateTime.utc(2026, 12, 1),
            createdAt: DateTime.utc(2026, 1, 1)));

    expect((await ds.findAll()).map((r) => r.id.value), ['new', 'old']);
    expect(await ds.findAll(scope: const UserId.value('u-2')), isEmpty);
  });

  test('mutations with no active user throw', () async {
    final signedOut = DriftPrescriptionsDataSource(db, () => null);
    expect(() => signedOut.put(const PrescriptionId.value('x'), sample('x')), throwsA(isA<NoActiveUserException>()));
    expect(await signedOut.findAll(), isEmpty);
  });
}
