import 'dart:typed_data';

import 'package:core/core.dart';

import '../../domain/value_objects/emergency_card_payload.dart';
import '../../domain/value_objects/sealed_card.dart';
import 'device_key_store.dart';

/// Seals an emergency card for one viewer's device key and opens one sealed
/// for this phone. The binding — link id, owner account id and version — goes
/// into the AAD, so a card cannot be replayed onto another link, passed off as
/// another owner's, or rolled back to an older version unnoticed.
abstract class CardSealer {
  Future<SealedCard> seal(
    EmergencyCardPayload card, {
    required Uint8List viewerPublicKey,
    required String linkId,
    required String ownerAccountId,
    required int version,
  });

  /// A [ValidationFailure] when the card was not sealed for [keyPair], was
  /// tampered with, or is bound to another link, owner or version.
  Future<AppResult<EmergencyCardPayload>> open(
    SealedCard sealed, {
    required DeviceKeyPair keyPair,
    required String linkId,
    required String ownerAccountId,
  });
}
