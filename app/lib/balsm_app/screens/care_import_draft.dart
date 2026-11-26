import 'package:collection/collection.dart' show ListEquality, SetEquality;
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;
import 'package:profile/profile.dart';

/// What the contact-import sheet holds: the contacts picked from the phone's
/// address book and which of them are ticked. Personal data — never log it.
@immutable
class CareImportDraft {
  CareImportDraft({List<ImportedContact> picked = const [], Set<String> selected = const {}})
      : picked = List.unmodifiable(picked),
        selected = Set.unmodifiable(selected);

  /// Picked so far, newest last.
  final List<ImportedContact> picked;

  /// Ids currently ticked.
  final Set<String> selected;

  /// Adds what the picker returned, each ticked — the patient chose it a
  /// moment ago. The OS lets the same contact be chosen twice (or under two
  /// ids with one number); the sheet lists it once.
  CareImportDraft add(Iterable<ImportedContact> contacts) {
    final picked = [...this.picked];
    final selected = {...this.selected};
    for (final c in contacts) {
      final key = _phoneKey(c);
      if (picked.any((p) => p.id == c.id || (key.isNotEmpty && _phoneKey(p) == key))) continue;
      picked.add(c);
      selected.add(c.id);
    }
    return CareImportDraft(picked: picked, selected: selected);
  }

  CareImportDraft toggle(String id) => CareImportDraft(
        picked: picked,
        selected: selected.contains(id) ? selected.difference({id}) : {...selected, id},
      );

  /// Ticks every one of [ids], or clears them all when [allOn].
  CareImportDraft toggleAll(Iterable<String> ids, {required bool allOn}) => CareImportDraft(
        picked: picked,
        selected: allOn ? selected.difference(ids.toSet()) : {...selected, ...ids},
      );

  /// The patient corrected the proposed type of contact [id].
  CareImportDraft withType(String id, CareProviderType type) => CareImportDraft(
        picked: picked.map((p) => p.id == id ? p.withType(type) : p).toList(),
        selected: selected,
      );

  /// Ticked contacts not already on [team] — what Import adds.
  List<ImportedContact> chosen(List<CareProvider> team) =>
      picked.where((c) => selected.contains(c.id) && !c.isAlreadyOnTeam(team)).toList();

  static String _phoneKey(ImportedContact c) => contactPhoneKey(c.phones.isEmpty ? null : c.phones.first);

  /// [ImportedContact] has no `==` of its own, so a retyped contact (a new
  /// object from `withType`) never equals the one it replaced.
  @override
  bool operator ==(Object other) =>
      other is CareImportDraft &&
      const ListEquality<ImportedContact>().equals(other.picked, picked) &&
      const SetEquality<String>().equals(other.selected, selected);

  @override
  int get hashCode => Object.hash(Object.hashAll(picked), Object.hashAllUnordered(selected));
}

class CareImportNotifier extends Notifier<CareImportDraft> {
  CareImportNotifier(this.form);

  /// A token the sheet's State creates once.
  final Object form;

  @override
  CareImportDraft build() => CareImportDraft();

  /// Opens the OS contact picker and adds what comes back. False when the
  /// patient picked nothing.
  Future<bool> pick() async {
    final picked = await ref.read(contactPickerProvider).pick();
    if (!ref.mounted) return false;
    if (picked == null || picked.isEmpty) return false;
    state = state.add(picked);
    return true;
  }

  void toggle(String id) => state = state.toggle(id);
  void toggleAll(Iterable<String> ids, {required bool allOn}) => state = state.toggleAll(ids, allOn: allOn);
  void setType(String id, CareProviderType type) => state = state.withType(id, type);
}

/// Auto-disposing: the picked contacts leave memory with the sheet.
final NotifierProviderFamily<CareImportNotifier, CareImportDraft, Object> careImportProvider =
    NotifierProvider.autoDispose.family<CareImportNotifier, CareImportDraft, Object>(CareImportNotifier.new);
