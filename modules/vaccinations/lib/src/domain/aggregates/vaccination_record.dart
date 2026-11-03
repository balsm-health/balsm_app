import 'package:core/core.dart';

import '../value_objects/ids.dart';

/// One dose of a vaccine given to a person, copied by hand from their paper
/// vaccination card (design `MCVaccAddScreen`). Partitioned by the person's
/// health profile; the partition is the data source's scope, not a field.
///
/// Rules ([violationsOf]): a vaccine name (free text, as written on the
/// card), a dose number of at least 1, a day given that is not after today,
/// an optional clinic, and an optional next due day after the day given.
///
/// PHI: on-device only, never logged.
class VaccinationRecord {
  /// Rehydrates a stored record. New records go through [record], which
  /// enforces the rules.
  const VaccinationRecord({
    required this.id,
    required this.vaccine,
    required this.doseNumber,
    required this.administeredOn,
    required this.createdAt,
    this.clinic,
    this.nextDueOn,
  });

  static const maxVaccineLength = 80;
  static const maxClinicLength = 80;

  final VaccinationRecordId id;

  /// The vaccine's name as written on the card.
  final String vaccine;

  /// Which dose of [vaccine] this was, from 1.
  final int doseNumber;

  /// The day it was given (a calendar day, UTC midnight).
  final DateTime administeredOn;

  /// Where it was given, when the patient entered it.
  final String? clinic;

  /// The day the next dose is due, as the card or the doctor says.
  final DateTime? nextDueOn;

  final DateTime createdAt;

  /// Every rule the given values break as of [now] (empty = can be saved).
  static List<VaccinationViolation> violationsOf({
    required String vaccine,
    required int doseNumber,
    required DateTime? administeredOn,
    required DateTime now,
    String? clinic,
    DateTime? nextDueOn,
  }) {
    final v = <VaccinationViolation>[];
    final name = vaccine.trim();
    if (name.isEmpty) v.add(VaccinationViolation.vaccineRequired);
    if (name.length > maxVaccineLength) v.add(VaccinationViolation.vaccineTooLong);
    if (doseNumber < 1) v.add(VaccinationViolation.doseNumberInvalid);
    if (administeredOn == null) {
      v.add(VaccinationViolation.administeredOnRequired);
    } else if (_day(administeredOn).isAfter(_day(now))) {
      v.add(VaccinationViolation.administeredInFuture);
    }
    if ((clinic?.trim().length ?? 0) > maxClinicLength) v.add(VaccinationViolation.clinicTooLong);
    if (nextDueOn != null && administeredOn != null && !_day(nextDueOn).isAfter(_day(administeredOn))) {
      v.add(VaccinationViolation.nextDueNotAfterAdministered);
    }
    return v;
  }

  /// A new record from the add form; or a [ValidationFailure] whose message
  /// lists every broken rule's code, comma-separated.
  static AppResult<VaccinationRecord> record({
    required String vaccine,
    required int doseNumber,
    required DateTime? administeredOn,
    required DateTime now,
    String? clinic,
    DateTime? nextDueOn,
    VaccinationRecordId? id,
  }) {
    final broken = violationsOf(
      vaccine: vaccine,
      doseNumber: doseNumber,
      administeredOn: administeredOn,
      now: now,
      clinic: clinic,
      nextDueOn: nextDueOn,
    );
    if (broken.isNotEmpty) return AppResult.failure(ValidationFailure(broken.map((b) => b.name).join(',')));
    final place = clinic?.trim() ?? '';
    return AppResult.success(VaccinationRecord(
      id: id ?? VaccinationRecordId.uuid(),
      vaccine: vaccine.trim(),
      doseNumber: doseNumber,
      administeredOn: _day(administeredOn!),
      clinic: place.isEmpty ? null : place,
      nextDueOn: nextDueOn == null ? null : _day(nextDueOn),
      createdAt: now.toUtc(),
    ));
  }

  /// Groups doses of the same vaccine whatever the spacing or case it was
  /// typed in.
  String get vaccineKey => vaccine.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static DateTime _day(DateTime d) => DateTime.utc(d.year, d.month, d.day);
}

/// A broken [VaccinationRecord] rule; [name] is the machine-readable code.
enum VaccinationViolation {
  vaccineRequired,
  vaccineTooLong,
  doseNumberInvalid,
  administeredOnRequired,
  administeredInFuture,
  clinicTooLong,
  nextDueNotAfterAdministered,
}
