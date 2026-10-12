sealed class AppFailure {
  const AppFailure(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

final class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message);
}

final class NotFoundFailure extends AppFailure {
  const NotFoundFailure([super.message = 'Not found']);
}

final class ConflictFailure extends AppFailure {
  const ConflictFailure([super.message = 'Conflict']);
}

final class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure([super.message = 'Unauthorized']);
}

final class NetworkFailure extends AppFailure {
  const NetworkFailure([super.message = 'Network error']);
}

final class StorageFailure extends AppFailure {
  const StorageFailure([super.message = 'Storage error']);
}

final class AgeGateFailure extends AppFailure {
  const AgeGateFailure([super.message = 'Must be 18 or older']);
}

final class GeofenceFailure extends AppFailure {
  const GeofenceFailure([super.message = 'Service not available in your region']);
}

/// The request never reached a server.
///
/// Narrower than [NetworkFailure], which is the catch-all for anything
/// unexpected. Only this one means "you are offline" — and only this one
/// justifies serving cached data past its TTL.
final class OfflineFailure extends AppFailure {
  const OfflineFailure([super.message = 'No connection']);
}
