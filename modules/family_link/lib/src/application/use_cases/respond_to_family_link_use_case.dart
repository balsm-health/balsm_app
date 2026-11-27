import 'dart:convert';

import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';

import '../link_failures.dart';
import '../ports/device_key_store.dart';
import '../ports/link_local_store.dart';

/// The recipient's answer to a pending request. Approving sends this phone's
/// public key, so the requester can seal their card for it; it shares nothing
/// by itself — each side's card stays off until its owner turns it on.
class RespondToFamilyLinkUseCase {
  RespondToFamilyLinkUseCase({
    required FamilyLinksApi api,
    required DeviceKeyStore keys,
    required LinkLocalStore local,
  })  : _api = api,
        _keys = keys,
        _local = local;

  final FamilyLinksApi _api;
  final DeviceKeyStore _keys;
  final LinkLocalStore _local;

  /// `POST /api/v1/family-links/{id}/approve`.
  Future<AppResult<void>> approve(String linkId) async {
    final key = base64.encode((await _keys.ensure()).publicKey);
    try {
      await _api.approve(linkId, FamilyLinkKeyRequest(publicKey: key));
    } on ApiException catch (e) {
      return AppResult.failure(linkFailure(e));
    }
    await _local.write(linkId, (await _local.read(linkId)).copyWith(uploadedKey: key));
    return AppResult.success(null);
  }

  /// `POST /api/v1/family-links/{id}/decline`.
  Future<AppResult<void>> decline(String linkId) async {
    try {
      await _api.decline(linkId);
    } on ApiException catch (e) {
      return AppResult.failure(linkFailure(e));
    }
    await _local.remove(linkId);
    return AppResult.success(null);
  }
}
