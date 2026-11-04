/// One family link as the caller sees it (`GET /api/v1/family-links/{id}`,
/// and each row of the incoming and outgoing lists).
///
/// Everything about the other party is "other_…": their account id, display
/// name and @handle (withheld from the requester until approval), and their
/// device public key. No health data is ever part of a link.
class FamilyLinkResponse {
  const FamilyLinkResponse({
    required this.id,
    required this.relation,
    required this.status,
    required this.direction,
    required this.createdAt,
    this.updatedAt,
    this.otherAccountId,
    this.otherDisplayName,
    this.otherHandle,
    this.otherPublicKey,
    this.cardSharedByMe = false,
    this.cardSharedWithMe = false,
  });

  final String id;
  final String relation;

  /// `pending` · `linked` · `declined` · `cancelled` · `unlinked` (lower case).
  final String status;

  /// The caller's side: `outgoing` (they asked) or `incoming` (they were asked).
  final String direction;

  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? otherAccountId;
  final String? otherDisplayName;
  final String? otherHandle;

  /// The other party's device X25519 public key (base64), when they have one.
  final String? otherPublicKey;

  /// Whether the caller has a sealed card stored on this link for the other party.
  final bool cardSharedByMe;

  /// Whether the other party has a sealed card stored on this link for the caller.
  final bool cardSharedWithMe;

  /// [direction] defaults to [fallbackDirection] — the list a row came from
  /// already says which side the caller is on.
  factory FamilyLinkResponse.fromJson(Map<String, dynamic> json, {String fallbackDirection = 'outgoing'}) =>
      FamilyLinkResponse(
        id: json['id'] as String,
        relation: json['relation'] as String? ?? 'other',
        // Enum names come over the wire as the server spells them ("Pending").
        status: (json['status'] as String? ?? 'pending').toLowerCase(),
        direction: (json['direction'] as String? ?? fallbackDirection).toLowerCase(),
        createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
        updatedAt: _date(json['updated_at']),
        otherAccountId: json['other_account_id'] as String?,
        otherDisplayName: json['other_display_name'] as String?,
        otherHandle: json['other_handle'] as String?,
        otherPublicKey: json['other_public_key'] as String?,
        cardSharedByMe: json['card_shared_by_me'] as bool? ?? false,
        cardSharedWithMe: json['card_shared_with_me'] as bool? ?? false,
      );

  static DateTime? _date(Object? raw) => raw is String ? DateTime.parse(raw).toUtc() : null;
}

/// `GET /api/v1/family-links/{id}/card` — the newest card the other party
/// sealed for the caller. Opaque: only the caller's device key opens it.
class SealedCardResponse {
  const SealedCardResponse({
    required this.version,
    required this.ephemeralPublicKey,
    required this.nonce,
    required this.ciphertext,
    required this.updatedAt,
  });

  final int version;
  final String ephemeralPublicKey;
  final String nonce;
  final String ciphertext;
  final DateTime updatedAt;

  factory SealedCardResponse.fromJson(Map<String, dynamic> json) => SealedCardResponse(
        version: (json['version'] as num).toInt(),
        ephemeralPublicKey: json['ephemeral_public_key'] as String,
        nonce: json['nonce'] as String,
        ciphertext: json['ciphertext'] as String,
        updatedAt: DateTime.parse(json['updated_at'] as String).toUtc(),
      );
}
