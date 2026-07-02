import 'package:balsm_api/balsm_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'balsm_api_controller.dart';

/// Root override point — the app's ProviderScope must override this with a
/// constructed [BalsmApiController] (same contract the old
/// balsmApiClientProvider had).
final balsmApiControllerProvider = Provider<BalsmApiController>((ref) {
  throw UnimplementedError('Override balsmApiControllerProvider in ProviderScope');
});

final balsmApiClientProvider = Provider<BalsmApiClient>((ref) {
  return ref.watch(balsmApiControllerProvider).client;
});

/// TEMPORARY during the balsm_api migration — deleted once no module reads
/// raw Dio anymore.
final dioClientProvider = Provider<Dio>((ref) {
  return ref.watch(balsmApiClientProvider).dio;
});

// One Provider<XxxApi> per area is appended here by each area task.

final emergencyQrApiProvider = Provider<EmergencyQrApi>((ref) {
  return DioEmergencyQrApi(dio: ref.watch(balsmApiClientProvider).dio);
});

final sessionsApiProvider = Provider<SessionsApi>((ref) {
  return DioSessionsApi(dio: ref.watch(balsmApiClientProvider).dio);
});

final deletionApiProvider = Provider<DeletionApi>((ref) {
  return DioDeletionApi(dio: ref.watch(balsmApiClientProvider).dio);
});
