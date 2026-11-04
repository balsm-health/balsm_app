import 'dart:convert';
import 'dart:typed_data';

import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';

import '../../domain/entities/family_link.dart';
import '../../domain/value_objects/emergency_card_payload.dart';
import '../../domain/value_objects/sealed_card.dart';
import '../link_failures.dart';
import '../ports/card_sealer.dart';
import '../ports/device_key_store.dart';

/// A card the other party shares, opened on this phone.
class SharedCard {
  const SharedCard({required this.card, required this.updatedAt});

  final EmergencyCardPayload card;
  final DateTime updatedAt;
}

/// Fetches the other party's sealed card for this account and opens it with
/// this phone's key (`GET /api/v1/family-links/{id}/card`).
///
/// Success with null: nothing is shared. [ValidationFailure]: a card exists
/// but does not open here — sealed for an older key of this account (a new
/// phone), until the owner's app re-seals on its next pull.
class ReadSharedCardUseCase {
  ReadSharedCardUseCase({required FamilyLinksApi api, required CardSealer sealer, required DeviceKeyStore keys})
      : _api = api,
        _sealer = sealer,
        _keys = keys;

  final FamilyLinksApi _api;
  final CardSealer _sealer;
  final DeviceKeyStore _keys;

  Future<AppResult<SharedCard?>> call(FamilyLink link) async {
    final owner = link.otherAccountId;
    if (!link.isLinked || owner == null) return AppResult.success(null);
    final SealedCardResponse? res;
    try {
      res = await _api.getCard(link.id);
    } on ApiException catch (e) {
      return AppResult.failure(linkFailure(e));
    }
    if (res == null) return AppResult.success(null);
    final Uint8List epk, nonce, ciphertext;
    try {
      epk = base64.decode(res.ephemeralPublicKey);
      nonce = base64.decode(res.nonce);
      ciphertext = base64.decode(res.ciphertext);
    } on FormatException {
      return AppResult.failure(const ValidationFailure('family_card_corrupt'));
    }
    final opened = await _sealer.open(
      SealedCard(version: res.version, ephemeralPublicKey: epk, nonce: nonce, ciphertext: ciphertext),
      keyPair: await _keys.ensure(),
      linkId: link.id,
      ownerAccountId: owner,
    );
    final updatedAt = res.updatedAt;
    return opened.fold(
      (card) => AppResult.success(SharedCard(card: card, updatedAt: updatedAt)),
      AppResult.failure,
    );
  }
}
