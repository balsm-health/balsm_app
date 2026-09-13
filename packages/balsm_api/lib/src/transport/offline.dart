import 'dart:io';

import 'package:dio/dio.dart';

/// The dio failure types that mean no server was reached.
///
/// Listed positively, with everything else defaulting to "not offline". An
/// exhaustive `switch` would be stricter but does not survive dio adding a
/// case — and the packages in this workspace do not all resolve the same dio
/// minor, so a case added in one would fail to compile in another. Defaulting
/// to false is also the safe direction: a new type misread as offline would
/// serve stale data, while one misread as a server error only means an error
/// is shown.
const _offlineTypes = {
  DioExceptionType.connectionError,
  DioExceptionType.connectionTimeout,
  DioExceptionType.sendTimeout,
  DioExceptionType.receiveTimeout,
};

/// Whether [error] means the request never reached a server.
///
/// One implementation so every layer agrees. The distinction it draws is what
/// makes a stale-fallback cache safe: a transport failure may be answered from
/// cache, but a 500, a 401 or a malformed body must not be — serving stale data
/// for those would turn a server bug into silent, endless staleness.
///
/// A cancellation is NOT offline: the map cancels superseded requests on every
/// settled pan, and treating that as offline would flag a working connection.
/// Nor is a transform timeout — the bytes arrived and decoding them was slow.
bool isOfflineError(Object error) {
  if (error is SocketException) return true;
  if (error is! DioException) return false;
  if (_offlineTypes.contains(error.type)) return true;
  // dio wraps the underlying transport error on `unknown`.
  return error.type == DioExceptionType.unknown && error.error is SocketException;
}
