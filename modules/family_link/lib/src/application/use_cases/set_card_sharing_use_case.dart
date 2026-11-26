import 'dart:convert';

import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';

import '../../domain/entities/family_link.dart';
import '../link_failures.dart';
import '../ports/card_sealer.dart';
import '../ports/link_local_store.dart';
import '../ports/own_emergency_card_reader.dart';

/// The owner's switch for sharing their own emergency card over one link, and
/// the re-seal that keeps a shared card current.
///
/// On: fetch the other party's public key (`GET /family-links/{id}`), seal the
/// card for it, `PUT /family-links/{id}/card`. Off: `DELETE …/card` — the
/// server purges the ciphertext. A card is sealed again only when its fields
/// or the viewer's key changed since the last upload ([resealIfStale]).
class SetCardSharingUseCase {
  SetCardSharingUseCase({
    required FamilyLinksApi api,
    required CardSealer sealer,
    required LinkLocalStore local,
    required OwnEmergencyCardReader card,
    required String? Function() ownerAccountId,
    DateTime Function()? now,
  })  : _api = api,
        _sealer = sealer,
        _local = local,
        _card = card,
        _owner = ownerAccountId,
        _now = now ?? DateTime.now;

  final FamilyLinksApi _api;
  final CardSealer _sealer;
  final LinkLocalStore _local;
  final OwnEmergencyCardReader _card;
  final String? Function() _owner;
  final DateTime Function() _now;

  Future<AppResult<void>> call(FamilyLink link, {required bool on}) async {
    if (on && !link.canShareCard) return AppResult.failure(const ConflictFailure('family_link_not_linked'));
    final state = await _local.read(link.id);
    if (!on) {
      try {
        await _api.deleteCard(link.id);
      } on ApiException catch (e) {
        return AppResult.failure(linkFailure(e));
      }
      await _local.write(link.id, state.copyWith(cardSharing: false, clearFingerprint: true));
      return AppResult.success(null);
    }
    return _seal(link.id, state.copyWith(cardSharing: true), force: true);
  }

  /// Re-seals and uploads the card over [link] when sharing is on and either
  /// the card or the viewer's key changed. Success when there was nothing to do.
  Future<AppResult<void>> resealIfStale(FamilyLink link) async {
    final state = await _local.read(link.id);
    if (!state.cardSharing || !link.canShareCard) return AppResult.success(null);
    return _seal(link.id, state, force: false);
  }

  Future<AppResult<void>> _seal(String linkId, LinkLocalState state, {required bool force}) async {
    final owner = _owner();
    if (owner == null) return AppResult.failure(const UnauthorizedFailure());
    final card = await _card.read();
    if (card == null) return AppResult.failure(const StorageFailure('family_card_unreadable'));
    try {
      final viewerKey = (await _api.get(linkId)).otherPublicKey;
      if (viewerKey == null || viewerKey.isEmpty) {
        // Nothing to seal for yet; keep the switch so the next pull shares it.
        await _local.write(linkId, state);
        return AppResult.failure(const NotFoundFailure('family_link_no_viewer_key'));
      }
      final fingerprint = '${await card.fingerprint()}.$viewerKey';
      if (!force && fingerprint == state.sealedFingerprint) return AppResult.success(null);
      final version = _nextVersion(state.sealedVersion);
      final sealed = await _sealer.seal(
        card,
        viewerPublicKey: base64.decode(viewerKey),
        linkId: linkId,
        ownerAccountId: owner,
        version: version,
      );
      await _api.putCard(
        linkId,
        PutSealedCardRequest(
          version: version,
          ephemeralPublicKey: base64.encode(sealed.ephemeralPublicKey),
          nonce: base64.encode(sealed.nonce),
          ciphertext: base64.encode(sealed.ciphertext),
        ),
      );
      await _local.write(linkId, state.copyWith(sealedFingerprint: fingerprint, sealedVersion: version));
      return AppResult.success(null);
    } on ApiException catch (e) {
      return AppResult.failure(linkFailure(e));
    } on FormatException {
      return AppResult.failure(const ValidationFailure('family_link_bad_viewer_key'));
    }
  }

  /// Versions only grow: the clock in milliseconds, so a reinstalled phone
  /// with no memory of its last version still moves forward.
  int _nextVersion(int last) {
    final clock = _now().millisecondsSinceEpoch;
    return clock > last ? clock : last + 1;
  }
}
