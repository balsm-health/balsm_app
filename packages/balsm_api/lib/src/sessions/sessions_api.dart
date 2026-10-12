import 'package:dio/dio.dart' show CancelToken;

import 'responses.dart';

/// Session-management endpoints (.NET module: Sessions).
/// All methods throw [ApiException] on transport or envelope errors.
/// Pass a [CancelToken] to abort the request; a cancelled request throws
/// [ApiException] with `isCancelled == true`.
abstract class SessionsApi {
  /// GET /sessions
  Future<List<SessionResponse>> listSessions({CancelToken? cancelToken});

  /// DELETE /sessions/{sessionId}
  Future<void> revokeSession(String sessionId, {CancelToken? cancelToken});

  /// POST /sessions/revoke-all
  Future<RevokeAllSessionsResponse> revokeAllSessions({CancelToken? cancelToken});
}
