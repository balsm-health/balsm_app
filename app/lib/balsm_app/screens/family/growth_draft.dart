import 'package:family/family.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;

/// What the growth log's form holds besides the typed weight and height
/// (those stay in its text controllers): the day measured, and the stored
/// entry loaded into the form when it edits one.
///
/// PHI: lives only while the screen is open (auto-dispose), never logged.
@immutable
class GrowthDraft {
  const GrowthDraft({required this.day, this.editing});

  /// An entry loaded to edit: the form takes its day.
  factory GrowthDraft.editing(GrowthEntry entry) => GrowthDraft(day: entry.measuredOn, editing: entry);

  final DateTime day;

  /// The entry loaded into the form, or null when the form adds a new one.
  final GrowthEntry? editing;

  GrowthDraft withDay(DateTime d) => GrowthDraft(day: d, editing: editing);

  // `GrowthEntry` has no value equality, so two loads of the same stored entry
  // compare by instance: a reload always notifies, an unchanged draft never does.
  @override
  bool operator ==(Object other) => other is GrowthDraft && other.day == day && identical(other.editing, editing);

  @override
  int get hashCode => Object.hash(day, identityHashCode(editing));
}

class GrowthDraftNotifier extends Notifier<GrowthDraft> {
  GrowthDraftNotifier(this.form);

  /// A token the screen's State creates once, so two open logs never share.
  final Object form;

  @override
  GrowthDraft build() => GrowthDraft(day: DateTime.now());

  void setDay(DateTime d) => state = state.withDay(d);

  void startEdit(GrowthEntry e) => state = GrowthDraft.editing(e);

  /// Back to adding a new entry, dated today.
  void reset() => state = GrowthDraft(day: DateTime.now());
}

final NotifierProviderFamily<GrowthDraftNotifier, GrowthDraft, Object> growthDraftProvider =
    NotifierProvider.autoDispose.family<GrowthDraftNotifier, GrowthDraft, Object>(GrowthDraftNotifier.new);
