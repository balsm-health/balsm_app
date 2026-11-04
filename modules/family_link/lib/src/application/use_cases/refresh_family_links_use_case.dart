import 'dart:convert';

import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';

import '../../domain/entities/family_link.dart';
import '../../domain/value_objects/link_direction.dart';
import '../../domain/value_objects/link_relation.dart';
import '../link_failures.dart';
import '../ports/device_key_store.dart';
import '../ports/link_local_store.dart';
import 'set_card_sharing_use_case.dart';

/// Pulls both lists — the only way this phone learns of a request or an
/// approval, since there is no push (app start, resume, the Family screen,
/// pull-to-refresh).
///
/// Then keeps each open link current from this side: sends this phone's
/// public key where the server holds another one (a new phone, a cleared
/// store), and re-seals a shared card whose fields or viewer key changed.
/// Local state for links that ended is dropped. Those follow-ups are best
/// effort: an offline step is retried on the next pull.
class RefreshFamilyLinksUseCase {
  RefreshFamilyLinksUseCase({
    required FamilyLinksApi api,
    required DeviceKeyStore keys,
    required LinkLocalStore local,
    required SetCardSharingUseCase sharing,
  })  : _api = api,
        _keys = keys,
        _local = local,
        _sharing = sharing;

  final FamilyLinksApi _api;
  final DeviceKeyStore _keys;
  final LinkLocalStore _local;
  final SetCardSharingUseCase _sharing;

  Future<AppResult<FamilyLinks>> call() async {
    final List<List<FamilyLinkResponse>> lists;
    try {
      lists = await Future.wait([_api.incoming(), _api.outgoing()]);
    } on ApiException catch (e) {
      return AppResult.failure(linkFailure(e));
    }
    final [incoming, outgoing] = lists;
    final states = await _local.readAll();
    final links = FamilyLinks(
      incoming: [for (final r in incoming) _link(r, states[r.id])],
      outgoing: [for (final r in outgoing) _link(r, states[r.id])],
    );
    await _forgetEnded(links, states);
    await _keepCurrent(links);
    return AppResult.success(links);
  }

  static FamilyLink _link(FamilyLinkResponse r, LinkLocalState? state) => FamilyLink(
        id: r.id,
        relation: LinkRelation.fromWire(r.relation),
        status: FamilyLinkStatus.tryFromWire(r.status) ?? FamilyLinkStatus.pending,
        direction: LinkDirection.fromWire(r.direction),
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
        otherAccountId: r.otherAccountId,
        otherDisplayName: r.otherDisplayName,
        otherHandle: r.otherHandle,
        otherPublicKey: r.otherPublicKey,
        cardSharedWithMe: r.cardSharedWithMe,
        cardSharing: state?.cardSharing ?? false,
        scanned: state?.scanned,
      );

  Future<void> _forgetEnded(FamilyLinks links, Map<String, LinkLocalState> states) async {
    for (final l in [...links.incoming, ...links.outgoing]) {
      if (!l.status.isOpen && states.containsKey(l.id)) await _local.remove(l.id);
    }
  }

  Future<void> _keepCurrent(FamilyLinks links) async {
    final mine = base64.encode((await _keys.ensure()).publicKey);
    final open = [
      ...links.outgoing.where((l) => l.status.isOpen),
      ...links.incoming.where((l) => l.isLinked),
    ];
    for (final link in open) {
      final state = await _local.read(link.id);
      if (state.uploadedKey != mine) {
        try {
          await _api.putKeys(link.id, FamilyLinkKeyRequest(publicKey: mine));
          await _local.write(link.id, state.copyWith(uploadedKey: mine));
        } on ApiException {
          // Retried on the next pull; the other side keeps an older key meanwhile.
        }
      }
      if (link.isLinked) await _sharing.resealIfStale(link);
    }
  }
}
