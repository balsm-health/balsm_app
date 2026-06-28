import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

enum NotificationPermissionState { granted, denied, provisional, notRequested }

final notificationPermissionStateProvider =
    StateNotifierProvider<_PermissionNotifier, NotificationPermissionState>(
  (ref) => _PermissionNotifier(),
);

class _PermissionNotifier extends StateNotifier<NotificationPermissionState> {
  _PermissionNotifier() : super(NotificationPermissionState.notRequested) {
    _refresh();
  }

  Future<void> _refresh() async {
    final status = await Permission.notification.status;
    final next = switch (status) {
      PermissionStatus.granted => NotificationPermissionState.granted,
      PermissionStatus.provisional => NotificationPermissionState.provisional,
      PermissionStatus.denied => NotificationPermissionState.denied,
      _ => NotificationPermissionState.notRequested,
    };
    if (mounted) state = next;
  }

  Future<void> refresh() => _refresh();
}
