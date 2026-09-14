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

  /// GET /emergency-qr/active — the caller's active token, or null.
  Future<ActiveQrResponse?> active({CancelToken? cancelToken});

  /// GET /emergency-qr/resolve/{tokenId} — public, unauthenticated.
  Future<ResolveQrResponse> resolve(String tokenId, {CancelToken? cancelToken});

  /// PUT /emergency-qr/{tokenId}/ciphertext — replace the encrypted snapshot
  /// in place (permanent-QR data refresh). Owner-only, active tokens only.
  Future<void> updateCiphertext(String tokenId, UpdateQrCiphertextRequest request, {CancelToken? cancelToken});

  /// POST /emergency-qr/{tokenId}/revoke
  Future<void> revoke(String tokenId, {CancelToken? cancelToken});
}
