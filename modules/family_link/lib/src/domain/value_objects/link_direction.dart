/// Which side of a link the signed-in account is on.
enum LinkDirection {
  /// They asked: the request went out from this account.
  outgoing,

  /// They were asked: the request came in to this account.
  incoming;

  static LinkDirection fromWire(String? code) =>
      code?.trim().toLowerCase() == 'incoming' ? LinkDirection.incoming : LinkDirection.outgoing;
}
