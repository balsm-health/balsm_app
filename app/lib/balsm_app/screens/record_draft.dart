import 'package:collection/collection.dart' show ListEquality;
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;
import 'package:records/records.dart';

import '../widgets/photo_attach.dart';

/// What the add-record sheet holds while the patient fills it in: the type,
/// the date, the tags and the picked file. The title and the tag being typed
/// stay in their text fields. PHI — never log these values.
@immutable
class RecordDraft {
  RecordDraft({required this.takenAt, this.type, List<String> tags = const [], this.attach})
      : tags = List.unmodifiable(tags);

  /// An edit opens on [initial]; a new record on [initialType] (or the type
  /// picker, when null), dated [now].
  factory RecordDraft.from({required DateTime now, RecordDocument? initial, RecordType? initialType}) => RecordDraft(
        type: initial?.type ?? initialType,
        takenAt: initial?.takenAt ?? now,
        tags: initial?.tags ?? const [],
      );

  /// Null while the type picker shows.
  final RecordType? type;
  final DateTime takenAt;
  final List<String> tags;

  /// The picked file; a new record only. Compared by identity, as each pick
  /// is a new object.
  final PickedAttach? attach;

  RecordDraft _copy({DateTime? takenAt, List<String>? tags, PickedAttach? attach}) => RecordDraft(
        type: type,
        takenAt: takenAt ?? this.takenAt,
        tags: tags ?? this.tags,
        attach: attach ?? this.attach,
      );

  RecordDraft withType(RecordType? t) => RecordDraft(type: t, takenAt: takenAt, tags: tags, attach: attach);

  RecordDraft withDate(DateTime d) => _copy(takenAt: d);

  /// Trimmed; a blank or repeated tag is ignored.
  RecordDraft addTag(String tag) {
    final t = tag.trim();
    return t.isEmpty || tags.contains(t) ? this : _copy(tags: [...tags, t]);
  }

  RecordDraft removeTag(String tag) => _copy(tags: tags.where((t) => t != tag).toList());

  RecordDraft withAttach(PickedAttach? a) => RecordDraft(type: type, takenAt: takenAt, tags: tags, attach: a);

  bool get canSave => type != null;

  @override
  bool operator ==(Object other) =>
      other is RecordDraft &&
      other.type == type &&
      other.takenAt == takenAt &&
      identical(other.attach, attach) &&
      const ListEquality<String>().equals(other.tags, tags);

  @override
  int get hashCode => Object.hash(type, takenAt, identityHashCode(attach), Object.hashAll(tags));
}

/// One sheet: `form` is a token its State creates once; `initial` the record
/// an edit opens on; `initialType` the type a shortcut opened it with.
typedef RecordDraftKey = ({Object form, RecordDocument? initial, RecordType? initialType});

class RecordDraftNotifier extends Notifier<RecordDraft> {
  RecordDraftNotifier(this.args);
  final RecordDraftKey args;

  @override
  RecordDraft build() => RecordDraft.from(now: DateTime.now(), initial: args.initial, initialType: args.initialType);

  void setType(RecordType? t) => state = state.withType(t);
  void setDate(DateTime d) => state = state.withDate(d);
  void addTag(String tag) => state = state.addTag(tag);
  void removeTag(String tag) => state = state.removeTag(tag);
  void attach(PickedAttach? a) => state = state.withAttach(a);
}

/// Auto-disposing: the draft, attachment bytes included, leaves memory with
/// the sheet.
final NotifierProviderFamily<RecordDraftNotifier, RecordDraft, RecordDraftKey> recordDraftProvider =
    NotifierProvider.autoDispose.family<RecordDraftNotifier, RecordDraft, RecordDraftKey>(RecordDraftNotifier.new);
