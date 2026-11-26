import 'package:family_link/family_link.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;

import '../../widgets/qr_scan_resolve.dart';

/// The scan-to-link request being put together: whose profile QR was
/// scanned, and how they are related to the account holder.
///
/// PHI: the scanned name and date of birth live only while the screen is
/// open (auto-dispose); they are never sent or logged.
@immutable
class LinkScanDraft {
  const LinkScanDraft({this.found, this.relation});

  final ScannedProfile? found;
  final LinkRelation? relation;

  bool get canSend => found != null && relation != null;

  @override
  bool operator ==(Object other) => other is LinkScanDraft && other.found == found && other.relation == relation;

  @override
  int get hashCode => Object.hash(found, relation);
}

class LinkScanDraftNotifier extends Notifier<LinkScanDraft> {
  LinkScanDraftNotifier(this.screen);

  /// A token the screen's State creates once.
  final Object screen;

  @override
  LinkScanDraft build() => const LinkScanDraft();

  /// A code was scanned: confirm who it is.
  void found(ScannedProfile p) => state = LinkScanDraft(found: p, relation: state.relation);

  /// Back to the camera; a relation already picked stays picked.
  void back() => state = LinkScanDraft(relation: state.relation);

  void setRelation(LinkRelation r) => state = LinkScanDraft(found: state.found, relation: r);

  /// "Scan another code": back to the camera with nothing picked.
  void scanAgain() => state = const LinkScanDraft();
}

final NotifierProviderFamily<LinkScanDraftNotifier, LinkScanDraft, Object> linkScanDraftProvider =
    NotifierProvider.autoDispose.family<LinkScanDraftNotifier, LinkScanDraft, Object>(LinkScanDraftNotifier.new);
