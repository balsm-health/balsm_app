import 'package:dio/dio.dart' show CancelToken;

import 'requests.dart';
import 'responses.dart';

/// Emergency QR endpoints (.NET module: EmergencyQr).
/// All methods throw [ApiException] on transport or envelope errors.
/// Pass a [CancelToken] to abort the request; a cancelled request throws
/// [ApiException] with `isCancelled == true`.
abstract class EmergencyQrApi {
  /// POST /emergency-qr/mint
  Future<MintQrResponse> mint(MintQrRequest request, {CancelToken? cancelToken});

  /// GET /emergency-qr/resolve/{tokenId} — public, unauthenticated.
  Future<ResolveQrResponse> resolve(String tokenId, {CancelToken? cancelToken});

  /// POST /emergency-qr/revoke
  Future<void> revoke(RevokeQrRequest request, {CancelToken? cancelToken});
}
