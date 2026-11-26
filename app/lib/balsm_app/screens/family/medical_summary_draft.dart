import 'package:core/core.dart';
import 'package:flutter/foundation.dart' show immutable, listEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;
import 'package:profile/profile.dart' show HealthProfile;

import '../profile_subscreens.dart' show memberHealthProfileProvider;

/// A member's medical summary while the form edits it: blood type (null is
/// "not sure"), allergies and long-term conditions by name.
///
/// PHI: lives only while the form is open (auto-dispose), never logged.
@immutable
class MedicalSummaryDraft {
  MedicalSummaryDraft({this.blood, List<String> allergies = const [], List<String> conditions = const []})
      : allergies = List.unmodifiable(allergies),
        conditions = List.unmodifiable(conditions);

  /// The stored profile, copied into the form.
  factory MedicalSummaryDraft.from(HealthProfile h) => MedicalSummaryDraft(
        blood: h.bloodType,
        allergies: h.allergies.map((a) => a.name).toList(),
        conditions: h.conditions.map((c) => c.name).toList(),
      );

  final BloodType? blood;
  final List<String> allergies;
  final List<String> conditions;

  MedicalSummaryDraft withBlood(BloodType? b) =>
      MedicalSummaryDraft(blood: b, allergies: allergies, conditions: conditions);

  MedicalSummaryDraft withAllergies(List<String> v) =>
      MedicalSummaryDraft(blood: blood, allergies: v, conditions: conditions);

  MedicalSummaryDraft withConditions(List<String> v) =>
      MedicalSummaryDraft(blood: blood, allergies: allergies, conditions: v);

  @override
  bool operator ==(Object other) =>
      other is MedicalSummaryDraft &&
      other.blood == blood &&
      listEquals(other.allergies, allergies) &&
      listEquals(other.conditions, conditions);

  @override
  int get hashCode => Object.hash(blood, Object.hashAll(allergies), Object.hashAll(conditions));
}

/// One open form on member `id`; `form` is a token its State creates once.
typedef MedicalSummaryKey = ({Object form, HealthProfileId id});

/// Null until the stored profile has loaded; then seeded from it once, so a
/// reload (the form refreshes the profile after every save, failed or not)
/// never throws away what the user is typing.
class MedicalSummaryDraftNotifier extends Notifier<MedicalSummaryDraft?> {
  MedicalSummaryDraftNotifier(this.args);
  final MedicalSummaryKey args;

  @override
  MedicalSummaryDraft? build() {
    final stored = ref.listen(memberHealthProfileProvider(args.id), (_, next) {
      final h = next.value;
      if (state == null && h != null) state = MedicalSummaryDraft.from(h);
    });
    return switch (stored.read().value) { final h? => MedicalSummaryDraft.from(h), _ => null };
  }

  void setBlood(BloodType? b) => _edit((d) => d.withBlood(b));
  void setAllergies(List<String> v) => _edit((d) => d.withAllergies(v));
  void setConditions(List<String> v) => _edit((d) => d.withConditions(v));

  void _edit(MedicalSummaryDraft Function(MedicalSummaryDraft) change) {
    if (state case final d?) state = change(d);
  }
}

final NotifierProviderFamily<MedicalSummaryDraftNotifier, MedicalSummaryDraft?, MedicalSummaryKey>
    medicalSummaryDraftProvider =
    NotifierProvider.autoDispose.family<MedicalSummaryDraftNotifier, MedicalSummaryDraft?, MedicalSummaryKey>(
  MedicalSummaryDraftNotifier.new,
);
