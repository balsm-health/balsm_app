import 'package:balsm_api/balsm_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/events/session_expired.dart';
import '../event_bus/event_bus.dart';

/// Attaches the persisted bearer token to every authenticated request and
/// transparently refreshes it on a `401`.
///
/// The access token is written to secure storage after OTP-verify / social
/// sign-in / recovery-claim (key [_kAccess]). Nothing attached it to outgoing
/// requests before this interceptor existed, so every authenticated endpoint
/// (account, sessions, deletion, emergency-QR, disclosure, …) returned `401`.
///
/// Flow:
///  - `onRequest`: for non-bootstrap paths, add `Authorization: Bearer <token>`
///    when a token is stored.
///  - `onError` `401`: refresh once (single-flight — concurrent 401s share one
///    refresh), persist the rotated pair, and replay the original request with
///    the new token. If refresh is impossible (no refresh token / device id) or
///    itself fails, clear the tokens and publish [SessionExpired].
///
/// Refresh + replay reuse the shared client [Dio]. This is a plain
/// [Interceptor] (no queue barrier), so re-entrant calls do not deadlock, and
/// recursion is closed off by the guards: `/auth/refresh` is a bootstrap path
/// (`onError` passes its 401 straight through) and the replayed request carries
/// [_retriedFlag] (so a second 401 is not retried again).
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required BalsmApiClient client,
    required FlutterSecureStorage storage,
    required EventBus bus,
  })  : _client = client,
        _storage = storage,
        _bus = bus;

  final BalsmApiClient _client;
  final FlutterSecureStorage _storage;
  final EventBus _bus;

  // Must match the keys the auth use-cases persist under.
  static const _kAccess = 'balsm.access_token';
  static const _kRefresh = 'balsm.refresh_token';
  static const _kUserId = 'balsm.user_id';
  static const _kDeviceId = 'balsm.device_id';
  static const _retriedFlag = '__balsm_auth_retried';

  Future<String?>? _inFlightRefresh;

  /// Token-issuing endpoints: they must never carry a (possibly stale) bearer
  /// token, and a `401` from them is a genuine auth failure — not an access
  /// token expiry to refresh-and-retry.
  bool _isBootstrap(String path) =>
      path.startsWith('/auth/otp') ||
      path == ApiRoutes.auth_google ||
      path == ApiRoutes.auth_apple ||
      path == ApiRoutes.auth_refresh ||
      path == ApiRoutes.auth_recovery_claim;

  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    if (!_isBootstrap(options.path)) {
      final token = await _storage.read(key: _kAccess);
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    final req = err.requestOptions;
    if (err.response?.statusCode != 401 ||
        _isBootstrap(req.path) ||
        req.extra[_retriedFlag] == true) {
      return handler.next(err);
    }

    final newToken = await _refresh();
    if (newToken == null) return handler.next(err);

    try {
      req.extra[_retriedFlag] = true;
      req.headers['Authorization'] = 'Bearer $newToken';
      final res = await _client.dio.fetch<dynamic>(req);
      return handler.resolve(res);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  /// Single-flight refresh: concurrent 401s await one in-flight refresh instead
  /// of each firing their own (which would rotate the refresh token N times and
  /// invalidate all but the last).
  Future<String?> _refresh() => _inFlightRefresh ??=
      _doRefresh().whenComplete(() => _inFlightRefresh = null);

  Future<String?> _doRefresh() async {
    final refresh = await _storage.read(key: _kRefresh);
    final deviceId = await _storage.read(key: _kDeviceId);
    if (refresh == null ||
        refresh.isEmpty ||
        deviceId == null ||
        deviceId.isEmpty) {
      await _signOut();
      return null;
    }
    try {
      // /auth/refresh is FLAT (no envelope): body is {access_token, refresh_token}.
      // Bootstrap path → onRequest attaches no token, onError ignores its 401.
      final res = await _client.dio.post<Map<String, dynamic>>(
        ApiRoutes.auth_refresh,
        data: {'refresh_token': refresh, 'device_id': deviceId},
      );
      final data = res.data ?? const <String, dynamic>{};
      final access = data['access_token'] as String?;
      final rotated = data['refresh_token'] as String?;
      if (access == null ||
          access.isEmpty ||
          rotated == null ||
          rotated.isEmpty) {
        await _signOut();
        return null;
      }
      await _storage.write(key: _kAccess, value: access);
      await _storage.write(key: _kRefresh, value: rotated);
      return access;
    } on DioException {
      await _signOut();
      return null;
    }
  }

  Future<void> _signOut() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
    await _storage.delete(key: _kUserId);
    _bus.publish(const SessionExpired());
  }
}
