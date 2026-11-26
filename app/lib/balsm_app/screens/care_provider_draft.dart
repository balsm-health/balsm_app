import 'dart:async';

import 'package:flutter/foundation.dart' show immutable, listEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;
import 'package:profile/profile.dart';

/// The parts of the Add / Edit care provider sheet that are not text: the
/// provider type, and in add mode the files attached before the row exists.
/// The text fields stay in their controllers. Who treats a patient is PHI.
@immutable
class CareProviderDraft {
  CareProviderDraft({this.type = CareProviderType.doctor, List<CareProviderFile> staged = const []})
      : staged = List.unmodifiable(staged);

  final CareProviderType type;

  /// Vault paths and links attached in add mode, written with the provider
  /// once the save gives it an id. Unmodifiable.
  final List<CareProviderFile> staged;

  CareProviderDraft withType(CareProviderType t) => CareProviderDraft(type: t, staged: staged);

  /// A file already staged is not staged twice.
  CareProviderDraft stage(CareProviderFile file) =>
      staged.contains(file) ? this : CareProviderDraft(type: type, staged: [...staged, file]);

  CareProviderDraft unstage(CareProviderFile file) =>
      CareProviderDraft(type: type, staged: staged.where((f) => f != file).toList());

  @override
  bool operator ==(Object other) =>
      other is CareProviderDraft && other.type == type && listEquals(other.staged, staged);

  @override
  int get hashCode => Object.hash(type, Object.hashAll(staged));
}

/// One sheet instance: `form` is a token the sheet's State creates once, so
/// two sheets never share a draft; `initial` is the provider being edited.
typedef CareProviderDraftKey = ({Object form, CareProvider? initial});

/// Auto-disposed: the draft leaves memory when the sheet closes.
class CareProviderDraftNotifier extends Notifier<CareProviderDraft> {
  CareProviderDraftNotifier(this.args);
  final CareProviderDraftKey args;

  @override
  CareProviderDraft build() => CareProviderDraft(type: args.initial?.type ?? CareProviderType.doctor);

  void setType(CareProviderType t) => state = state.withType(t);
  void stage(CareProviderFile file) => state = state.stage(file);
  void unstage(CareProviderFile file) => state = state.unstage(file);
}

final NotifierProviderFamily<CareProviderDraftNotifier, CareProviderDraft, CareProviderDraftKey>
    careProviderDraftProvider =
    NotifierProvider.autoDispose.family<CareProviderDraftNotifier, CareProviderDraft, CareProviderDraftKey>(
  CareProviderDraftNotifier.new,
);

/// How many rows the last contacts import created, for the care-team banner.
/// Zero hides it; `home.jsx` clears it after 5 s rather than leaving it up.
class CareImportBannerNotifier extends Notifier<int> {
  static const shownFor = Duration(seconds: 5);

  Timer? _clear;

  @override
  int build() {
    ref.onDispose(() => _clear?.cancel());
    return 0;
  }

  void show(int created) {
    state = created;
    _clear?.cancel();
    _clear = Timer(shownFor, () {
      if (ref.mounted) state = 0;
    });
  }
}

final NotifierProvider<CareImportBannerNotifier, int> careImportBannerProvider =
    NotifierProvider.autoDispose<CareImportBannerNotifier, int>(CareImportBannerNotifier.new);
