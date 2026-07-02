import 'responses.dart';

/// Session-management endpoints (.NET module: Sessions).
/// All methods throw [ApiException] on transport or envelope errors.
abstract class SessionsApi {
  /// GET /sessions
  Future<List<SessionResponse>> listSessions();

  /// DELETE /sessions/{sessionId}
  Future<void> revokeSession(String sessionId);

  /// POST /sessions/revoke-all
  Future<RevokeAllSessionsResponse> revokeAllSessions();
}
