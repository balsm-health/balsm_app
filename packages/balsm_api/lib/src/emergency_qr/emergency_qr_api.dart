import 'requests.dart';
import 'responses.dart';

/// Emergency QR endpoints (.NET module: EmergencyQr).
/// All methods throw [ApiException] on transport or envelope errors.
abstract class EmergencyQrApi {
  /// POST /emergency-qr/mint
  Future<MintQrResponse> mint(MintQrRequest request);

  /// GET /emergency-qr/resolve/{tokenId} — public, unauthenticated.
  Future<ResolveQrResponse> resolve(String tokenId);

  /// POST /emergency-qr/revoke
  Future<void> revoke(RevokeQrRequest request);
}
