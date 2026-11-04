import 'package:dio/dio.dart' show CancelToken;

import 'requests.dart';
import 'responses.dart';

/// Family links between two Balsm accounts (Identity & Access): a request made
/// by scanning the other person's profile QR, approved in their own app, and
/// the end-to-end sealed emergency card either side may share.
///
/// The recipient learns of a request only by pulling [incoming] — there is no
/// push channel.
abstract class FamilyLinksApi {
  /// POST /api/v1/family-links — `404` unknown/revoked jti, `409` self-link or
  /// an open request/link for the pair, `422` bad relation, `429` rate limit.
  Future<void> create(CreateFamilyLinkRequest request, {CancelToken? cancelToken});

  /// GET /api/v1/family-links/incoming — requests made to the caller.
  /// [status] narrows the list (e.g. `pending`).
  Future<List<FamilyLinkResponse>> incoming({String? status, CancelToken? cancelToken});

  /// GET /api/v1/family-links/outgoing — requests the caller made.
  Future<List<FamilyLinkResponse>> outgoing({CancelToken? cancelToken});

  /// GET /api/v1/family-links/{id} — one link, with the other side's public key.
  Future<FamilyLinkResponse> get(String id, {CancelToken? cancelToken});

  /// POST /api/v1/family-links/{id}/approve — recipient only; `409` not pending.
  Future<void> approve(String id, FamilyLinkKeyRequest request, {CancelToken? cancelToken});

  /// POST /api/v1/family-links/{id}/decline — recipient only; `409` not pending.
  Future<void> decline(String id, {CancelToken? cancelToken});

  /// DELETE /api/v1/family-links/{id} — cancels a pending request (requester)
  /// or unlinks (either side). A `404` is success: the link is already gone
  /// for the caller.
  Future<void> delete(String id, {CancelToken? cancelToken});

  /// PUT /api/v1/family-links/{id}/keys — replace the caller's device public key.
  Future<void> putKeys(String id, FamilyLinkKeyRequest request, {CancelToken? cancelToken});

  /// PUT /api/v1/family-links/{id}/card — store the caller's card sealed for
  /// the other party. `409` not linked or stale version, `413` too large.
  Future<void> putCard(String id, PutSealedCardRequest request, {CancelToken? cancelToken});

  /// GET /api/v1/family-links/{id}/card — the other party's card for the
  /// caller, or null when none is shared (`404`).
  Future<SealedCardResponse?> getCard(String id, {CancelToken? cancelToken});

  /// DELETE /api/v1/family-links/{id}/card — stop sharing; the server purges
  /// the ciphertext. A `404` is success: nothing was shared.
  Future<void> deleteCard(String id, {CancelToken? cancelToken});
}
