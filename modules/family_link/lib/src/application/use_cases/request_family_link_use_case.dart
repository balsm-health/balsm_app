import 'dart:convert';

import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';

import '../../domain/entities/family_link.dart';
import '../../domain/value_objects/link_relation.dart';
import '../link_failures.dart';
import '../ports/device_key_store.dart';
import '../ports/link_local_store.dart';

/// Asks the owner of a scanned profile QR to link accounts
/// (`POST /api/v1/family-links`). The QR's [jti] is only a request handle —
/// the server resolves it to the account. This phone's public key goes with
/// the request so the recipient can later seal their card for it, and what
/// the scan showed is kept on this phone for the pending row.
///
/// Failures: [NotFoundFailure] for an unknown, revoked or expired code;
/// [ConflictFailure] for yourself or a pair already requested or linked.
class RequestFamilyLinkUseCase {
  RequestFamilyLinkUseCase({
    required FamilyLinksApi api,
    required DeviceKeyStore keys,
    required LinkLocalStore local,
    String Function()? newId,
  })  : _api = api,
        _keys = keys,
        _local = local,
        _newId = newId ?? (() => UuidV7.generate().toString());

  final FamilyLinksApi _api;
  final DeviceKeyStore _keys;
  final LinkLocalStore _local;
  final String Function() _newId;

  /// The new link's id on success.
  Future<AppResult<String>> call({
    required String jti,
    required LinkRelation relation,
    ScannedIdentity? scanned,
  }) async {
    final id = _newId();
    final key = base64.encode((await _keys.ensure()).publicKey);
    try {
      await _api.create(CreateFamilyLinkRequest(id: id, jti: jti, relation: relation.wire, publicKey: key));
    } on ApiException catch (e) {
      return AppResult.failure(linkFailure(e));
    }
    await _local.write(id, LinkLocalState(uploadedKey: key, scanned: scanned));
    return AppResult.success(id);
  }
}
