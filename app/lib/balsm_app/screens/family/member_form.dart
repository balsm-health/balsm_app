import 'package:core/core.dart';
import 'package:family/family.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;

/// The add / edit member form while it is open: the family module's
/// [MemberDraft] (what is saved and validated, the typed name and new group
/// name copied in as they change) plus the two answers the draft does not
/// keep — "not sure" of the blood type, and the adult's consent.
///
/// PHI: lives only while the form is open (auto-dispose), never logged.
@immutable
class MemberForm {
  const MemberForm({required this.draft, this.bloodUnsure = false, this.consent = false});

  /// The form opening on [editing]'s stored details, or empty.
  factory MemberForm.from(FamilyMember? editing) => MemberForm(
        draft: MemberDraft(
          displayName: editing?.displayName ?? '',
          relationship: editing?.relationship,
          dateOfBirth: editing?.dateOfBirth,
          sex: editing?.sex,
          bloodType: editing?.bloodType,
          groupId: editing?.groupId,
        ),
      );

  final MemberDraft draft;

  /// "Not sure" picked on the blood type grid (the draft's type is then null).
  final bool bloodUnsure;

  /// The account holder confirmed an adult member's consent.
  final bool consent;

  /// A new group is being named instead of an existing one picked.
  bool get newGroup => draft.newGroupName != null;

  // Nullable fields come wrapped in a record, so a transition can set them to
  // null; an absent record keeps the current value.
  MemberForm _with({
    String? displayName,
    Relationship? relationship,
    DateTime? dateOfBirth,
    Sex? sex,
    (BloodType?,)? blood,
    (MemberGroupId?, String?)? group,
    bool? bloodUnsure,
    bool? consent,
  }) =>
      MemberForm(
        draft: MemberDraft(
          displayName: displayName ?? draft.displayName,
          relationship: relationship ?? draft.relationship,
          dateOfBirth: dateOfBirth ?? draft.dateOfBirth,
          sex: sex ?? draft.sex,
          bloodType: blood == null ? draft.bloodType : blood.$1,
          groupId: group == null ? draft.groupId : group.$1,
          newGroupName: group == null ? draft.newGroupName : group.$2,
        ),
        bloodUnsure: bloodUnsure ?? this.bloodUnsure,
        consent: consent ?? this.consent,
      );

  MemberForm withName(String name) => _with(displayName: name);

  /// A relation chip; a chip that implies a sex (son, mother…) sets it too.
  MemberForm withRelation(Relationship relationship, {Sex? impliedSex}) =>
      _with(relationship: relationship, sex: impliedSex);

  MemberForm withSex(Sex sex) => _with(sex: sex);

  MemberForm withDob(DateTime dob) => _with(dateOfBirth: dob);

  /// A blood type, or null for "not sure".
  MemberForm withBlood(BloodType? b) => _with(blood: (b,), bloodUnsure: b == null);

  MemberForm withGroup(MemberGroupId id) => _with(group: (id, null));

  /// Start naming a new group; [typed] is what its field already holds.
  MemberForm startNewGroup(String typed) => _with(group: (draft.groupId, typed));

  MemberForm withNewGroupName(String name) => newGroup ? _with(group: (draft.groupId, name)) : this;

  MemberForm toggleConsent() => _with(consent: !consent);

  /// The draft breaks no rule as of [now].
  bool canSave(DateTime now) => draft.violations(now).isEmpty;

  /// An adult being added needs the consent step first; an edit never does.
  bool needsConsent(DateTime now, {required bool editing}) => !editing && draft.needsConsentOn(now);

  /// What is saved: an edit keeps the blood type as stored now ([storedBlood]),
  /// because it is changed on the medical profile, which the edit form opens.
  MemberDraft toSave({required bool editing, BloodType? storedBlood}) =>
      editing ? _with(blood: (storedBlood,)).draft : draft;

  @override
  bool operator ==(Object other) =>
      other is MemberForm && other.draft == draft && other.bloodUnsure == bloodUnsure && other.consent == consent;

  @override
  int get hashCode => Object.hash(draft, bloodUnsure, consent);
}

/// One open form: `form` is a token its State creates once; `editing` is the
/// member it edits (null to add one).
typedef MemberFormKey = ({Object form, FamilyMember? editing});

class MemberFormNotifier extends Notifier<MemberForm> {
  MemberFormNotifier(this.args);
  final MemberFormKey args;

  @override
  MemberForm build() => MemberForm.from(args.editing);

  void setName(String v) => state = state.withName(v);
  void pickRelation(Relationship r, {Sex? impliedSex}) => state = state.withRelation(r, impliedSex: impliedSex);
  void setSex(Sex v) => state = state.withSex(v);
  void setDob(DateTime v) => state = state.withDob(v);
  void setBlood(BloodType? v) => state = state.withBlood(v);
  void selectGroup(MemberGroupId id) => state = state.withGroup(id);
  void startNewGroup(String typed) => state = state.startNewGroup(typed);
  void setNewGroupName(String v) => state = state.withNewGroupName(v);
  void toggleConsent() => state = state.toggleConsent();
}

final NotifierProviderFamily<MemberFormNotifier, MemberForm, MemberFormKey> memberFormProvider =
    NotifierProvider.autoDispose.family<MemberFormNotifier, MemberForm, MemberFormKey>(MemberFormNotifier.new);
