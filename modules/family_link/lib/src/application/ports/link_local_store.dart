import '../../domain/entities/family_link.dart';

/// What this phone remembers about one link. Kept in the platform secure
/// store: [scanned] is PHI.
class LinkLocalState {
  const LinkLocalState({
    this.cardSharing = false,
    this.sealedFingerprint,
    this.sealedVersion = 0,
    this.uploadedKey,
    this.scanned,
  });

  /// The owner switched on sharing their emergency card over this link.
  final bool cardSharing;

  /// Card fingerprint + viewer key the last uploaded card was sealed from;
  /// a change in either means the card must be sealed again.
  final String? sealedFingerprint;

  /// Version of the last uploaded card.
  final int sealedVersion;

  /// The public key this phone last sent for the link (base64).
  final String? uploadedKey;

  /// Outgoing only: what the requester's scan showed.
  final ScannedIdentity? scanned;

  LinkLocalState copyWith({
    bool? cardSharing,
    String? sealedFingerprint,
    bool clearFingerprint = false,
    int? sealedVersion,
    String? uploadedKey,
    ScannedIdentity? scanned,
  }) =>
      LinkLocalState(
        cardSharing: cardSharing ?? this.cardSharing,
        sealedFingerprint: clearFingerprint ? null : sealedFingerprint ?? this.sealedFingerprint,
        sealedVersion: sealedVersion ?? this.sealedVersion,
        uploadedKey: uploadedKey ?? this.uploadedKey,
        scanned: scanned ?? this.scanned,
      );
}

/// Per-link device state, keyed by link id, scoped to the signed-in account.
abstract class LinkLocalStore {
  Future<Map<String, LinkLocalState>> readAll();
  Future<LinkLocalState> read(String linkId);
  Future<void> write(String linkId, LinkLocalState state);
  Future<void> remove(String linkId);
}
