import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

enum NotificationPermissionState { granted, denied, provisional, notRequested }

final notificationPermissionStateProvider =
    NotifierProvider<_PermissionNotifier, NotificationPermissionState>(_PermissionNotifier.new);

class _PermissionNotifier extends Notifier<NotificationPermissionState> {
  @override
  NotificationPermissionState build() {
    // Reads the OS state once the provider is first used; until then nothing has been asked.
    unawaited(_refresh());
    return NotificationPermissionState.notRequested;
  }

  Future<void> _refresh() async {
    final status = await Permission.notification.status;
    final next = switch (status) {
      PermissionStatus.granted => NotificationPermissionState.granted,
      PermissionStatus.provisional => NotificationPermissionState.provisional,
      PermissionStatus.denied => NotificationPermissionState.denied,
      _ => NotificationPermissionState.notRequested,
    };
    if (ref.mounted) state = next;
  }

  Future<void> refresh() => _refresh();
}
