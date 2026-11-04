import 'package:core/core.dart';

import '../value_objects/link_direction.dart';
import '../value_objects/link_relation.dart';

/// What the requester's own scan showed them about the other person — kept on
/// the requester's phone only, because the server withholds the recipient's
/// name until they approve. PHI (name, date of birth): never logged.
class ScannedIdentity {
  const ScannedIdentity({this.name, this.dateOfBirth});

  final String? name;

  /// Calendar date, `yyyy-MM-dd`.
  final String? dateOfBirth;

  DateTime? get dateOfBirthDay {
    final raw = dateOfBirth;
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Map<String, dynamic> toJson() => {'name': name, 'dob': dateOfBirth};

  factory ScannedIdentity.fromJson(Map<String, dynamic> json) =>
      ScannedIdentity(name: json['name'] as String?, dateOfBirth: json['dob'] as String?);
}

/// The signed-in account's view of one link to another Balsm account (read
/// model of the server's `FamilyLink` aggregate, which owns the state machine:
/// `pending → linked | declined | cancelled`, `linked → unlinked`).
///
/// [cardSharing] is this phone's switch for sharing the account holder's own
/// emergency card over the link — off until they turn it on.
class FamilyLink {
  const FamilyLink({
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
    this.cardSharedWithMe = false,
    this.cardSharing = false,
    this.scanned,
  });

  final String id;
  final LinkRelation relation;
  final FamilyLinkStatus status;
  final LinkDirection direction;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? otherAccountId;
  final String? otherDisplayName;
  final String? otherHandle;

  /// The other party's device X25519 public key (base64), when known.
  final String? otherPublicKey;

  /// The other party has a sealed card stored for this account.
  final bool cardSharedWithMe;

  /// This account shares its own emergency card over the link.
  final bool cardSharing;

  /// Outgoing only: what the requester's scan showed.
  final ScannedIdentity? scanned;

  bool get isPending => status == FamilyLinkStatus.pending;
  bool get isLinked => status == FamilyLinkStatus.linked;
  bool get isIncoming => direction == LinkDirection.incoming;

  /// The recipient decides a pending request.
  bool get canRespond => isIncoming && isPending;

  /// The requester can withdraw a pending request.
  bool get canCancel => !isIncoming && isPending;

  /// Either side can end a link.
  bool get canUnlink => isLinked;

  /// A card can be shared only over a link.
  bool get canShareCard => isLinked;

  /// The name to show: the server's once it gives one, else the requester's
  /// own scan. Empty when neither is known.
  String get displayName {
    final server = otherDisplayName?.trim() ?? '';
    if (server.isNotEmpty) return server;
    return scanned?.name?.trim() ?? '';
  }

  FamilyLink copyWith({bool? cardSharing, ScannedIdentity? scanned}) => FamilyLink(
        id: id,
        relation: relation,
        status: status,
        direction: direction,
        createdAt: createdAt,
        updatedAt: updatedAt,
        otherAccountId: otherAccountId,
        otherDisplayName: otherDisplayName,
        otherHandle: otherHandle,
        otherPublicKey: otherPublicKey,
        cardSharedWithMe: cardSharedWithMe,
        cardSharing: cardSharing ?? this.cardSharing,
        scanned: scanned ?? this.scanned,
      );
}

/// Both lists, as the Family screen shows them.
class FamilyLinks {
  const FamilyLinks({this.incoming = const [], this.outgoing = const []});

  static const empty = FamilyLinks();

  final List<FamilyLink> incoming;
  final List<FamilyLink> outgoing;

  /// Requests waiting for this account's answer — what the avatar dot counts.
  List<FamilyLink> get awaitingMe => [
        for (final l in incoming)
          if (l.canRespond) l
      ];

  /// Requests this account sent that are still waiting.
  List<FamilyLink> get waiting => [
        for (final l in outgoing)
          if (l.isPending) l
      ];

  /// Every open link, either direction, oldest first.
  List<FamilyLink> get linked => [
        for (final l in [...outgoing, ...incoming])
          if (l.isLinked) l
      ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  FamilyLink? byId(String id) {
    for (final l in [...incoming, ...outgoing]) {
      if (l.id == id) return l;
    }
    return null;
  }
}
