import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the patient chose "Use on this device only" on the pre-sign-in
/// maintenance page. While it holds (and maintenance only pauses, not blocks),
/// the page stops covering the device-only sign-up it sent them to.
class MaintenanceDeviceOnlyNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void choose() => state = true;
}

final NotifierProvider<MaintenanceDeviceOnlyNotifier, bool> maintenanceDeviceOnlyProvider =
    NotifierProvider<MaintenanceDeviceOnlyNotifier, bool>(MaintenanceDeviceOnlyNotifier.new);
