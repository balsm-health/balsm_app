import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;
import 'package:vaccinations/vaccinations.dart';

/// What the add / edit vaccination form holds while it is open: the dose
/// number and the two days. The vaccine name and clinic stay in the form's
/// text controllers and are passed in where the rules need them.
///
/// PHI: lives only while the form is open (auto-dispose), never logged.
@immutable
class VaccinationDraft {
  const VaccinationDraft({required this.dose, required this.given, this.next});

  /// The form opening on [editing], or on a new dose ([dose] from a past-due
  /// row, else 1) given on [today].
  factory VaccinationDraft.from({required DateTime today, VaccinationRecord? editing, int? dose}) => VaccinationDraft(
        dose: editing?.doseNumber ?? dose ?? 1,
        given: editing?.administeredOn ?? today,
        next: editing?.nextDueOn,
      );

  final int dose;
  final DateTime given;

  /// The next dose's due day; optional, and always after [given].
  final DateTime? next;

  VaccinationDraft withDose(int n) => VaccinationDraft(dose: n, given: given, next: next);

  /// A next due day that is no longer after the day given is dropped.
  VaccinationDraft withGiven(DateTime d) {
    final due = next;
    return VaccinationDraft(dose: dose, given: d, next: due != null && due.isAfter(d) ? due : null);
  }

  VaccinationDraft withNext(DateTime? d) => VaccinationDraft(dose: dose, given: given, next: d);

  /// Every rule the form breaks with this draft and the typed [vaccine] and
  /// [clinic] (empty = it can be saved).
  List<VaccinationViolation> violations({required String vaccine, required String clinic, required DateTime now}) =>
      VaccinationRecord.violationsOf(
        vaccine: vaccine,
        doseNumber: dose,
        administeredOn: given,
        clinic: clinic,
        nextDueOn: next,
        now: now,
      );

  @override
  bool operator ==(Object other) =>
      other is VaccinationDraft && other.dose == dose && other.given == given && other.next == next;

  @override
  int get hashCode => Object.hash(dose, given, next);
}

/// One open form: `form` is a token its State creates once, so two forms
/// never share a draft; `editing` and `dose` are what it opens on.
typedef VaccinationDraftKey = ({Object form, VaccinationRecord? editing, int? dose});

class VaccinationDraftNotifier extends Notifier<VaccinationDraft> {
  VaccinationDraftNotifier(this.args);
  final VaccinationDraftKey args;

  @override
  VaccinationDraft build() => VaccinationDraft.from(today: DateTime.now(), editing: args.editing, dose: args.dose);

  void setDose(int n) => state = state.withDose(n);
  void setGiven(DateTime d) => state = state.withGiven(d);
  void setNext(DateTime? d) => state = state.withNext(d);
}

final NotifierProviderFamily<VaccinationDraftNotifier, VaccinationDraft, VaccinationDraftKey> vaccinationDraftProvider =
    NotifierProvider.autoDispose.family<VaccinationDraftNotifier, VaccinationDraft, VaccinationDraftKey>(
  VaccinationDraftNotifier.new,
);
