import 'package:connectivity_plus/connectivity_plus.dart';

/// Emits `true` whenever the device regains any network connection, `false`
/// when it drops to none. Drives [BackupService]'s offline-retry.
Stream<bool> connectivityOnlineStream() =>
    Connectivity().onConnectivityChanged.map((results) => results.any((r) => r != ConnectivityResult.none));
