/// Lifecycle of a family/caregiver account link.
///
/// [pending] is an outgoing request awaiting the other person's approval in
/// their own app — no health data is shared and the account cannot be
/// switched to until it becomes [linked]. Domain value: the server-side
/// link-request contract (Identity & Access — Caregiver/Guardianship, P002)
/// serializes these states; the app shell only renders them.
enum FamilyLinkStatus { linked, pending }
