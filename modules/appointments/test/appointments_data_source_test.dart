import 'package:appointments/appointments.dart';
import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftAppointmentsDataSource ds;
  const user = UserId.value('u-1');

  Appointment sample(String id, {DateTime? at, AppointmentKind kind = AppointmentKind.checkUp}) => Appointment(
        id: AppointmentId.value(id),
        userId: user,
        clinician: 'Dr. Layla Hassan',
        specialty: 'Cardiology',
        location: 'Cairo Clinic',
        kind: kind,
        startsAt: at ?? DateTime.utc(2026, 9, 1, 10),
        createdAt: DateTime.utc(2026, 8, 1),
      );

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    ds = DriftAppointmentsDataSource(db, () => user);
  });
  tearDown(() => db.close());

  test('write → read round-trips every field', () async {
    final a = sample('a1', kind: AppointmentKind.followUp);
    await ds.put(a.id, a);

    final got = await ds.find(a.id);
    expect(got, isNotNull);
    expect(got!.clinician, 'Dr. Layla Hassan');
    expect(got.specialty, 'Cardiology');
    expect(got.location, 'Cairo Clinic');
    expect(got.kind, AppointmentKind.followUp);
    expect(got.startsAt.toUtc(), DateTime.utc(2026, 9, 1, 10));
  });

  test('nullable fields survive a round trip', () async {
    final a = Appointment(
      id: const AppointmentId.value('a2'),
      userId: user,
      clinician: 'Self-recorded visit',
      startsAt: DateTime.utc(2026, 9, 2),
      createdAt: DateTime.utc(2026, 8, 1),
    );
    await ds.put(a.id, a);
    final got = await ds.find(a.id);
    expect(got!.specialty, isNull);
    expect(got.location, isNull);
    expect(got.kind, AppointmentKind.checkUp);
  });

  test('findAll is newest-first and user-scoped', () async {
    await ds.put(const AppointmentId.value('old'), sample('old', at: DateTime.utc(2026, 1, 1)));
    await ds.put(const AppointmentId.value('new'), sample('new', at: DateTime.utc(2026, 12, 1)));

    final all = await ds.findAll();
    expect(all.map((a) => a.id.value), ['new', 'old']);

    final other = await ds.findAll(scope: const UserId.value('u-2'));
    expect(other, isEmpty);
  });

  test('isUpcoming splits on the visit time', () {
    final now = DateTime.utc(2026, 6, 1);
    expect(sample('f', at: DateTime.utc(2026, 7, 1)).isUpcoming(now), isTrue);
    expect(sample('p', at: DateTime.utc(2026, 5, 1)).isUpcoming(now), isFalse);
  });

  test('delete removes the row', () async {
    final a = sample('a3');
    await ds.put(a.id, a);
    await ds.delete(a.id);
    expect(await ds.find(a.id), isNull);
  });

  test('mutations with no active user throw', () async {
    final signedOut = DriftAppointmentsDataSource(db, () => null);
    expect(() => signedOut.put(const AppointmentId.value('x'), sample('x')), throwsA(isA<NoActiveUserException>()));
    expect(await signedOut.findAll(), isEmpty);
  });
}
