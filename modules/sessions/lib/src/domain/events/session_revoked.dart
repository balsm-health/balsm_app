import 'package:core/core.dart';

import '../value_objects/ids.dart';

/// Emitted when a device session is revoked (single or via sign-out-everywhere).
class SessionRevoked extends AppEvent {
  const SessionRevoked({required this.sessionId, required this.deviceLabel});

  final SessionId sessionId;
  final String deviceLabel;

  @override
  String get eventName => 'session_revoked';

  // deviceLabel is a user-set device name, not PHI.
  @override
  Map<String, dynamic> toJson() => {
        'sessionId': sessionId.value,
        'deviceLabel': deviceLabel,
      };
}
