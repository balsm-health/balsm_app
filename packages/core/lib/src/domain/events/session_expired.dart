import 'app_event.dart';

/// Published when the API session can no longer be refreshed — the refresh
/// token is missing, expired, or rejected — so the access token cannot be
/// renewed. The transport ([AuthInterceptor]) has already cleared the stored
/// tokens; listeners should drop any in-session user identity and fall back to
/// the auth flow.
///
/// Lives in `core` (not the auth module) because the transport layer, which
/// detects the dead session, must not depend on `auth`. The app shell bridges
/// this to its own sign-out handling.
class SessionExpired extends AppEvent {
  const SessionExpired();

  @override
  String get eventName => 'session_expired';

  @override
  Map<String, dynamic> toJson() => const {};
}
