/// Fail-loud error model for local persistence (see storage design spec).
///
/// | op      | no active scope        | backend failure          | corrupt value             | absent |
/// |---------|------------------------|--------------------------|---------------------------|----------------|
/// | find    | return `null`          | [StorageWriteException]* | [StorageDecodeException]  | return `null`  |
/// | put     | [NoActiveUserException]/[NoActiveEntityException] | [StorageWriteException] | — | — |
/// | delete  | [NoActiveUserException]/[NoActiveEntityException] | [StorageWriteException] | — | no-op |
/// | clear   | **no-op** (idempotent logout cleanup)             | [StorageWriteException] | — | — |
///
/// *reads rethrow backend failures as [StorageException].
///
/// Rationale: silently dropping a write of health-adjacent data hides bugs.
/// A read returning `null` for "not there" is a value, not a failure — but a
/// present-yet-corrupt value is a real error and must surface.
sealed class StorageException implements Exception {
  const StorageException(this.message);
  final String message;
  @override
  String toString() => '$runtimeType: $message';
}

/// A user-scoped operation ran with no authenticated user and no explicit
/// scope override.
final class NoActiveUserException extends StorageException {
  const NoActiveUserException([super.message = 'no authenticated user']);
}

/// An entity-scoped operation ran with no active entity (facility) selected
/// and no explicit scope override.
final class NoActiveEntityException extends StorageException {
  const NoActiveEntityException([super.message = 'no active entity selected']);
}

/// The backend rejected or failed a mutation (or an encode failed).
final class StorageWriteException extends StorageException {
  const StorageWriteException(super.message, [this.cause]);
  final Object? cause;
}

/// A stored value exists but cannot be decoded into the expected type.
final class StorageDecodeException extends StorageException {
  const StorageDecodeException(super.message, [this.cause]);
  final Object? cause;
}
