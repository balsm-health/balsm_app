import '../domain/value_objects/user_id.dart';
import 'data_source.dart';

/// Data partitioned by user. Null scope = current authenticated user
/// (`currentUserIdProvider`); explicit [UserId] overrides.
///
/// Holds everything user-specific — including the user's data AT a facility
/// (appointments, prescriptions at clinic X: put the `EntityId` in the key or
/// value, keep the partition on the user). PHI lives here, never in
/// entity/global scope, so logout-wipe (`clear`) removes it reliably.
abstract class UserDataSource<K, V> extends ScopedDataSource<K, V, UserId> {}
