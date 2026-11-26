import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;

import 'qr_scan_resolve.dart';

/// The account sheet's "add family member" entry (home.jsx
/// AddFamilyMemberSheet): a name, a relation as the patient picked it (its
/// label, stored as is on the session-only family row), an optional date of
/// birth, and the profile QR it was scanned from, if any.
///
/// Not the family module's `MemberDraft`: that one is a managed profile with
/// a required `Relationship`, sex and date of birth; this row has a free
/// relation label, no sex, and only asks for a name.
///
/// PHI: lives only while the sheet is open (auto-dispose), never logged.
@immutable
class AddFamilyMemberDraft {
  const AddFamilyMemberDraft({this.name = '', this.relation = '', this.dob, this.scanned});

  final String name;

  /// The relation's label as picked; empty until one is.
  final String relation;
  final DateTime? dob;

  /// The profile QR scanned; null for a manual entry.
  final ScannedProfile? scanned;

  /// A name of at least two letters.
  bool get canSave => name.trim().length > 1;

  /// The name typed is the account holder's own ([selfName]): you cannot add
  /// yourself.
  bool isSelf(String selfName) => selfName.isNotEmpty && name.trim().toLowerCase() == selfName.toLowerCase();

  AddFamilyMemberDraft withName(String v) =>
      AddFamilyMemberDraft(name: v, relation: relation, dob: dob, scanned: scanned);

  AddFamilyMemberDraft withRelation(String v) =>
      AddFamilyMemberDraft(name: name, relation: v, dob: dob, scanned: scanned);

  AddFamilyMemberDraft withDob(DateTime v) =>
      AddFamilyMemberDraft(name: name, relation: relation, dob: v, scanned: scanned);

  /// A scanned profile fills the name and date of birth from its QR.
  AddFamilyMemberDraft applyScan(ScannedProfile p) => AddFamilyMemberDraft(
        name: p.payload.name ?? '',
        relation: relation,
        dob: DateTime.tryParse(p.payload.dateOfBirth ?? ''),
        scanned: p,
      );

  @override
  bool operator ==(Object other) =>
      other is AddFamilyMemberDraft &&
      other.name == name &&
      other.relation == relation &&
      other.dob == dob &&
      other.scanned == scanned;

  @override
  int get hashCode => Object.hash(name, relation, dob, scanned);
}

class AddFamilyMemberDraftNotifier extends Notifier<AddFamilyMemberDraft> {
  AddFamilyMemberDraftNotifier(this.sheet);

  /// A token the sheet's State creates once.
  final Object sheet;

  @override
  AddFamilyMemberDraft build() => const AddFamilyMemberDraft();

  void setName(String v) => state = state.withName(v);
  void setRelation(String v) => state = state.withRelation(v);
  void setDob(DateTime v) => state = state.withDob(v);
  void applyScan(ScannedProfile p) => state = state.applyScan(p);
}

final NotifierProviderFamily<AddFamilyMemberDraftNotifier, AddFamilyMemberDraft, Object> addFamilyMemberDraftProvider =
    NotifierProvider.autoDispose.family<AddFamilyMemberDraftNotifier, AddFamilyMemberDraft, Object>(
  AddFamilyMemberDraftNotifier.new,
);
