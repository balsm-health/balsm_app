import 'package:balsm_api/balsm_api.dart';
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

/// Shared transport wrapper — one per client, injected into every typed API.
final networkManagerProvider = Provider<NetworkManager>((ref) {
  return NetworkManager(dio: ref.watch(balsmApiClientProvider).dio);
});

// One Provider<XxxApi> per area, each backed by the shared NetworkManager.

final emergencyQrApiProvider = Provider<EmergencyQrApi>((ref) {
  return DioEmergencyQrApi(net: ref.watch(networkManagerProvider));
});

final sessionsApiProvider = Provider<SessionsApi>((ref) {
  return DioSessionsApi(net: ref.watch(networkManagerProvider));
});

final deletionApiProvider = Provider<DeletionApi>((ref) {
  return DioDeletionApi(net: ref.watch(networkManagerProvider));
});

final accountApiProvider = Provider<AccountApi>((ref) {
  return DioAccountApi(net: ref.watch(networkManagerProvider));
});

final authApiProvider = Provider<AuthApi>((ref) {
  return DioAuthApi(net: ref.watch(networkManagerProvider));
});

final disclosureApiProvider = Provider<DisclosureApi>((ref) {
  return DioDisclosureApi(net: ref.watch(networkManagerProvider));
});

final geofenceApiProvider = Provider<GeofenceApi>((ref) {
  return DioGeofenceApi(net: ref.watch(networkManagerProvider));
});

final careDirectoryApiProvider = Provider<CareDirectoryApi>((ref) {
  return DioCareDirectoryApi(net: ref.watch(networkManagerProvider));
});

/// Map-pack bytes downloader.
///
/// Deliberately NOT built on [balsmApiClientProvider]'s Dio: basemaps come
/// from a third-party CDN, and that client carries auth/PHI interceptors
/// whose headers have no business travelling to another host. It only borrows
/// the base url, to resolve the root-relative places urls the catalogue
/// returns for snapshots this server exports itself.
final mapPackFileDownloaderProvider = Provider<FileDownloader>(
  (ref) => DioFileDownloader(baseUrl: () => ref.read(balsmApiClientProvider).baseUrl),
);
