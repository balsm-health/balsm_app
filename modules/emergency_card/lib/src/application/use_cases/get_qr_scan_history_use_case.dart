import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Spec v2.0 scan history: the owner's own successful resolves — when and by
/// what coarse client class ("web" / "app"), never the scanner's identity.
class GetQrScanHistoryUseCase {
  GetQrScanHistoryUseCase({required EmergencyQrApi api}) : _api = api;

  final EmergencyQrApi _api;

  Future<AppResult<List<QrScanEntry>>> call() async {
    try {
      return AppResult.success(await _api.scans());
    } on ApiException catch (e) {
      if (e.isUnauthorized) return AppResult.failure(const UnauthorizedFailure());
      return AppResult.failure(const NetworkFailure('Could not load scan history'));
    }
  }
}

final getQrScanHistoryUseCaseProvider = Provider<GetQrScanHistoryUseCase>((ref) {
  return GetQrScanHistoryUseCase(api: ref.watch(emergencyQrApiProvider));
});
