import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prescriptions/prescriptions.dart';

void main() {
  late AppDatabase db;
  late DriftPrescriptionsDataSource ds;
  const user = UserId.value('u-1');
  late HealthProfileId self;
  // A second person on the same account (a managed dependent). Synthetic.
  const child = HealthProfileId.value('hp-child');
  HealthProfileId? active;

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

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    self = await db.ensureSelfHealthProfile(user);
    await db.customStatement("INSERT INTO health_profile (id, user_id, is_self, kind, updated_at) "
        "VALUES ('${child.value}', '${user.value}', 0, 'dependent', 0)");
    active = self;
    ds = DriftPrescriptionsDataSource(db, () => active);
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

  test('findAll is newest-first and profile-scoped', () async {
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
    expect(await ds.findAll(scope: child), isEmpty);
  });

  test('two profiles of one account are isolated from each other', () async {
    await ds.put(const PrescriptionId.value('mine'), sample('mine'));
    active = child;
    await ds.put(const PrescriptionId.value('kid'), sample('kid'));

    expect((await ds.findAll()).map((r) => r.id.value), ['kid']);
    expect(await ds.find(const PrescriptionId.value('mine')), isNull);
    await ds.delete(const PrescriptionId.value('mine')); // other partition: no-op
    expect((await ds.findAll(scope: self)).map((r) => r.id.value), ['mine']);
    expect((await ds.find(const PrescriptionId.value('kid')))!.userId, user);
  });

  test('put refuses a profile the prescription\'s account does not own', () async {
    final other = await db.ensureSelfHealthProfile(const UserId.value('u-2'));
    active = other;
    expect(() => ds.put(const PrescriptionId.value('x'), sample('x')), throwsA(isA<StorageWriteException>()));
  });

  test('self-added scripts keep title, source, and attachment', () async {
    final rx = Prescription(
      id: const PrescriptionId.value('self-1'),
      userId: user,
      clinician: 'Dr. Sara',
      title: 'Clinic visit',
      source: 'self',
      attachmentPath: 'u-1/rx.jpg.enc',
      attachmentKind: 'image',
      items: const [PrescribedItem(name: 'Amoxicillin', dose: '500 mg · One time', notes: 'with food')],
      issuedAt: DateTime.utc(2026, 9, 1),
      createdAt: DateTime.utc(2026, 9, 1),
    );
    await ds.put(rx.id, rx);
    final got = await ds.find(rx.id);
    expect(got, isNotNull);
    expect(got!.isSelf, isTrue);
    expect(got.title, 'Clinic visit');
    expect(got.attachmentKind, 'image');
    expect(got.items.single.notes, 'with food');
  });

  test('a clinic script with a reference is not self-added', () {
    expect(sample('clinic').isSelf, isFalse);
  });

  test('mutations with no active profile throw', () async {
    final signedOut = DriftPrescriptionsDataSource(db, () => null);
    expect(() => signedOut.put(const PrescriptionId.value('x'), sample('x')), throwsA(isA<NoActiveProfileException>()));
    expect(await signedOut.findAll(), isEmpty);
  });
}
