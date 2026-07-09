import 'package:core/core.dart';

/// Typed id of an emergency QR token — the JWT `jti` returned by the server's
/// mint endpoint. Appears in the public QR URL path.
class QrTokenId extends UniqueId {
  const QrTokenId.value(super.value) : super.value();
  const QrTokenId.empty() : super.empty();

  static QrTokenId? fromString(String? value) =>
      value?.mapNotNull((v) => QrTokenId.value(v));
}
