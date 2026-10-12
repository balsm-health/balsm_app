import '../domain/events/app_event.dart';
import 'permission_state.dart';

class NotificationPermissionChanged extends AppEvent {
  const NotificationPermissionChanged({
    required this.previousState,
    required this.newState,
  });

  final NotificationPermissionState previousState;
  final NotificationPermissionState newState;

  @override
  String get eventName => 'notification_permission_changed';

  @override
  Map<String, dynamic> toJson() => {
        'previousState': previousState.name,
        'newState': newState.name,
      };
}
