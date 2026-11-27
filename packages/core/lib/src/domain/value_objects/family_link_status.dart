/// Lifecycle of a family/caregiver account link.
///
/// [pending] is an outgoing request awaiting the other person's approval in
/// their own app — no health data is shared and the account cannot be
/// switched to until it becomes [linked]. A pending request ends [declined]
/// (by the recipient) or [cancelled] (by the requester); a link ends
/// [unlinked] (by either side). Domain value: the server-side link contract
/// (Identity & Access — Caregiver/Guardianship) serializes these states.
enum FamilyLinkStatus {
  linked,
  pending,
  declined,
  cancelled,
  unlinked;

  /// Stable wire code (the enum name). Locale-independent.
  String get wire => name;

  /// Parses a wire code, case-insensitively; null for an unknown one.
  static FamilyLinkStatus? tryFromWire(String? code) {
    final c = code?.trim().toLowerCase();
    for (final s in values) {
      if (s.name == c) return s;
    }
    return null;
  }

  /// Whether the link is still open: awaiting approval, or linked.
  bool get isOpen => this == pending || this == linked;
}
