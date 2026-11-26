import 'package:core/core.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;

import '../../application/use_cases/add_allergy_use_case.dart';
import '../../application/use_cases/add_chronic_condition_use_case.dart';
import '../../application/use_cases/add_emergency_contact_use_case.dart';
import '../../application/use_cases/remove_allergy_use_case.dart';
import '../../application/use_cases/remove_chronic_condition_use_case.dart';
import '../../application/use_cases/update_health_profile_use_case.dart';
import '../../domain/value_objects/allergy_severity.dart';
import '../../domain/value_objects/ids.dart';

/// Runs the health-profile editor's changes for the signed-in account holder
/// and holds the last failure (null when the last change succeeded).
///
/// The profile itself is read from the data source stream; this only writes.
/// The inputs are PHI and pass straight through to the use cases — the state
/// keeps only the failure, whose message carries validation or storage text,
/// never the values.
class ProfileEditNotifier extends Notifier<AppFailure?> {
  @override
  AppFailure? build() => null;

  void clearError() => state = null;

  Future<void> setBloodType(BloodType? bloodType) => _run(
        (userId) => ref.read(updateHealthProfileUseCaseProvider).execute(
              userId: userId,
              bloodType: bloodType,
              clearBloodType: bloodType == null,
            ),
      );

  Future<void> addAllergy({required String name, required String severity, required bool isControlled}) => _run(
        (userId) => ref.read(addAllergyUseCaseProvider).execute(
              userId: userId,
              name: name,
              severity: severity,
              isControlledSubstance: isControlled,
            ),
      );

  Future<void> removeAllergy(AllergyId allergyId) => _run(
        (userId) => ref.read(removeAllergyUseCaseProvider).execute(userId: userId, allergyId: allergyId),
      );

  Future<void> addCondition(String name) => _run(
        (userId) => ref.read(addChronicConditionUseCaseProvider).execute(userId: userId, name: name),
      );

  Future<void> removeCondition(ChronicConditionId conditionId) => _run(
        (userId) => ref.read(removeChronicConditionUseCaseProvider).execute(userId: userId, conditionId: conditionId),
      );

  Future<void> addContact({required String name, required String phone, String? relation}) => _run(
        (userId) => ref.read(addEmergencyContactUseCaseProvider).execute(
              userId: userId,
              name: name,
              phone: phone,
              relation: relation,
            ),
      );

  Future<void> _run(Future<AppResult<Object?>> Function(UserId userId) change) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    state = null;
    final result = await change(userId);
    if (!ref.mounted) return;
    if (result case AppFailureResult(:final failure)) state = failure;
  }
}

/// The editor's changes; dropped when the editor closes.
final NotifierProvider<ProfileEditNotifier, AppFailure?> profileEditProvider =
    NotifierProvider.autoDispose<ProfileEditNotifier, AppFailure?>(ProfileEditNotifier.new);

/// The add-allergy sheet's choices besides the name (which stays in its text
/// field): severity and the controlled-substance flag. PHI, so per sheet and
/// auto-disposed.
@immutable
class AllergyDraft {
  const AllergyDraft({this.severity = 'mild', this.controlled = false});

  /// Wire value, one of [AllergySeverity.wireValues].
  final String severity;
  final bool controlled;

  AllergyDraft withSeverity(String s) => AllergyDraft(severity: s, controlled: controlled);
  AllergyDraft withControlled({required bool value}) => AllergyDraft(severity: severity, controlled: value);

  @override
  bool operator ==(Object other) => other is AllergyDraft && other.severity == severity && other.controlled == controlled;

  @override
  int get hashCode => Object.hash(severity, controlled);
}

class AllergyDraftNotifier extends Notifier<AllergyDraft> {
  AllergyDraftNotifier(this.sheet);

  /// The sheet's identity token; only the family key, never read.
  final Object sheet;

  @override
  AllergyDraft build() => const AllergyDraft();

  void setSeverity(String s) => state = state.withSeverity(s);
  void setControlled({required bool value}) => state = state.withControlled(value: value);
}

/// One draft per open sheet, keyed by a token the sheet's State creates once.
final NotifierProviderFamily<AllergyDraftNotifier, AllergyDraft, Object> allergyDraftProvider =
    NotifierProvider.autoDispose.family<AllergyDraftNotifier, AllergyDraft, Object>(AllergyDraftNotifier.new);
