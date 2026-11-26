import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/aggregates/health_profile.dart';
import '../../infrastructure/drift/drift_profile_data_source.dart';
import '../ports/health_profiles_data_source.dart';
import 'add_allergy_use_case.dart';
import 'add_chronic_condition_use_case.dart';
import 'remove_allergy_use_case.dart';
import 'remove_chronic_condition_use_case.dart';
import 'update_health_profile_use_case.dart';

/// Saves a profile's medical summary as one form (mother-child.jsx
/// `MCMedicalScreen`): the blood type, and the allergy and chronic condition
/// names as the lists now read.
///
/// Compares with what is stored and changes only the difference: names no
/// longer listed are removed, new names are added (an allergy as `mild`, since
/// the form asks for a name only), and names kept keep their stored details.
/// Names compare trimmed and case-insensitively; blank and repeated names are
/// ignored. Each change goes through its own use case, so their rules and
/// events apply. Stops at the first failure and returns it.
///
/// PHI is written to the on-device store only — no network call, no PHI in
/// logs.
class SaveMedicalSummaryUseCase {
  const SaveMedicalSummaryUseCase({
    required HealthProfilesDataSource dao,
    required UpdateHealthProfileUseCase update,
    required AddAllergyUseCase addAllergy,
    required RemoveAllergyUseCase removeAllergy,
    required AddChronicConditionUseCase addCondition,
    required RemoveChronicConditionUseCase removeCondition,
  })  : _dao = dao,
        _update = update,
        _addAllergy = addAllergy,
        _removeAllergy = removeAllergy,
        _addCondition = addCondition,
        _removeCondition = removeCondition;

  final HealthProfilesDataSource _dao;
  final UpdateHealthProfileUseCase _update;
  final AddAllergyUseCase _addAllergy;
  final RemoveAllergyUseCase _removeAllergy;
  final AddChronicConditionUseCase _addCondition;
  final RemoveChronicConditionUseCase _removeCondition;

  /// [profileId] is a member profile of [userId], or null for the account
  /// holder's own. A missing or closed member fails with [NotFoundFailure].
  Future<AppResult<void>> execute({
    required UserId userId,
    required BloodType? bloodType,
    required List<String> allergies,
    required List<String> conditions,
    HealthProfileId? profileId,
  }) async {
    final HealthProfile? current;
    try {
      current = await _dao.resolveProfile(userId, profileId: profileId);
    } on Object catch (e) {
      return AppResult.failure(StorageFailure(e.toString()));
    }
    if (current == null && profileId != null) {
      return AppResult.failure(const NotFoundFailure('Health profile not found'));
    }

    if (current?.bloodType != bloodType) {
      final r = await _update.execute(
        userId: userId,
        profileId: profileId,
        bloodType: bloodType,
        clearBloodType: bloodType == null,
      );
      if (r.isFailure) return AppResult.failure(r.error);
    }

    final wantAllergies = _distinct(allergies);
    for (final a in current?.allergies ?? const <Allergy>[]) {
      if (wantAllergies.containsKey(_key(a.name))) continue;
      final r = await _removeAllergy.execute(userId: userId, profileId: profileId, allergyId: a.id);
      if (r.isFailure) return AppResult.failure(r.error);
    }
    final haveAllergies = {for (final a in current?.allergies ?? const <Allergy>[]) _key(a.name)};
    for (final e in wantAllergies.entries) {
      if (haveAllergies.contains(e.key)) continue;
      final r = await _addAllergy.execute(userId: userId, profileId: profileId, name: e.value, severity: 'mild');
      if (r.isFailure) return AppResult.failure(r.error);
    }

    final wantConditions = _distinct(conditions);
    for (final c in current?.conditions ?? const <ChronicCondition>[]) {
      if (wantConditions.containsKey(_key(c.name))) continue;
      final r = await _removeCondition.execute(userId: userId, profileId: profileId, conditionId: c.id);
      if (r.isFailure) return AppResult.failure(r.error);
    }
    final haveConditions = {for (final c in current?.conditions ?? const <ChronicCondition>[]) _key(c.name)};
    for (final e in wantConditions.entries) {
      if (haveConditions.contains(e.key)) continue;
      final r = await _addCondition.execute(userId: userId, profileId: profileId, name: e.value);
      if (r.isFailure) return AppResult.failure(r.error);
    }
    return AppResult.success(null);
  }

  static String _key(String name) => name.trim().toLowerCase();

  /// The listed names by comparison key, first spelling kept, blanks dropped.
  static Map<String, String> _distinct(List<String> names) {
    final out = <String, String>{};
    for (final n in names) {
      final t = n.trim();
      if (t.isNotEmpty) out.putIfAbsent(_key(t), () => t);
    }
    return out;
  }
}

final saveMedicalSummaryUseCaseProvider = Provider<SaveMedicalSummaryUseCase>((ref) {
  return SaveMedicalSummaryUseCase(
    dao: ref.watch(profileDataSourceProvider),
    update: ref.watch(updateHealthProfileUseCaseProvider),
    addAllergy: ref.watch(addAllergyUseCaseProvider),
    removeAllergy: ref.watch(removeAllergyUseCaseProvider),
    addCondition: ref.watch(addChronicConditionUseCaseProvider),
    removeCondition: ref.watch(removeChronicConditionUseCaseProvider),
  );
});
