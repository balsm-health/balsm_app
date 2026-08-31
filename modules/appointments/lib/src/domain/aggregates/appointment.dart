import 'package:core/core.dart';

import '../value_objects/ids.dart';

/// What kind of visit this is. Mirrors the two the design badges.
enum AppointmentKind { checkUp, followUp }

/// A scheduled visit. PHI, on-device only (SQLCipher).
///
/// Patient-entered: there is no provider directory yet, so [clinician] and
/// [specialty] are free text rather than a reference. `CareTeamScreen` takes
/// the same stance — the app does not fabricate clinicians.
class Appointment {
  const Appointment({
    required this.id,
    required this.userId,
    required this.clinician,
    this.specialty,
    this.location,
    this.kind = AppointmentKind.checkUp,
    required this.startsAt,
    required this.createdAt,
  });

  final AppointmentId id;
  final UserId userId;

  /// Who the visit is with, as the patient wrote it.
  final String clinician;

  final String? specialty;
  final String? location;
  final AppointmentKind kind;

  /// When the visit is (or was). Drives the upcoming/past split.
  final DateTime startsAt;

  final DateTime createdAt;

  /// Upcoming is simply "not yet started" — there is no confirmation state to
  /// track while this is patient-entered.
  bool isUpcoming([DateTime? now]) => startsAt.isAfter(now ?? DateTime.now());

  Appointment copyWith({
    String? clinician,
    String? specialty,
    String? location,
    AppointmentKind? kind,
    DateTime? startsAt,
  }) =>
      Appointment(
        id: id,
        userId: userId,
        clinician: clinician ?? this.clinician,
        specialty: specialty ?? this.specialty,
        location: location ?? this.location,
        kind: kind ?? this.kind,
        startsAt: startsAt ?? this.startsAt,
        createdAt: createdAt,
      );

  @override
  bool operator ==(Object other) => other is Appointment && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
