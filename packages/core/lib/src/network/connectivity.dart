import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Emits `true` while any network interface is up, `false` when none is.
///
/// Emits the CURRENT state immediately on subscribe.
/// `onConnectivityChanged` does not — a listener would otherwise know nothing
/// until the interface next changed, which on a device that booted offline is
/// never.
Stream<bool> connectivityOnlineStream() async* {
  final connectivity = Connectivity();
  yield _isOnline(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(_isOnline);
}

bool _isOnline(List<ConnectivityResult> results) => results.any((r) => r != ConnectivityResult.none);

/// Interface state for the UI — NOT a precondition for making requests.
///
/// `connectivity_plus` reports whether an interface is up, not whether a server
/// is reachable: a captive-portal Wi-Fi reports online with nothing routable
/// behind it. Gating requests on this would block working connections and admit
/// dead ones. Always attempt the request; let the failure decide.
final onlineProvider = StreamProvider<bool>((ref) => connectivityOnlineStream());
