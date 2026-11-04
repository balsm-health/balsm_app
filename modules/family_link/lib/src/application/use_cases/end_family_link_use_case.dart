import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';

import '../link_failures.dart';
import '../ports/link_local_store.dart';

/// Ends a link from this side (`DELETE /api/v1/family-links/{id}`): the
/// requester withdraws a pending request ([cancel]), or either side ends a
/// link ([unlink]). The server purges both shared cards; the link row and its
/// audit stay. This phone forgets its state for the link.
class EndFamilyLinkUseCase {
  EndFamilyLinkUseCase({required FamilyLinksApi api, required LinkLocalStore local})
      : _api = api,
        _local = local;

  final FamilyLinksApi _api;
  final LinkLocalStore _local;

  Future<AppResult<void>> cancel(String linkId) => _end(linkId);

  Future<AppResult<void>> unlink(String linkId) => _end(linkId);

  Future<AppResult<void>> _end(String linkId) async {
    try {
      await _api.delete(linkId);
    } on ApiException catch (e) {
      return AppResult.failure(linkFailure(e));
    }
    await _local.remove(linkId);
    return AppResult.success(null);
  }
}
