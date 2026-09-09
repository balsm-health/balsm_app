import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

/// Data partitioned by user. Null scope = current authenticated user
/// (`currentUserIdProvider`); explicit [UserId] overrides.
///
/// Holds everything user-specific — including the user's data AT a facility
/// (appointments, prescriptions at clinic X: put the `EntityId` in the key or
/// value, keep the partition on the user). PHI lives here, never in
/// entity/global scope, so logout-wipe (`clear`) removes it reliably.
abstract class UserEntityDataSource<K, V> extends ScopedDataSource<K, V, UserEntityFilter> {}

class UserEntityFilter extends Equatable {
  final UserId? userId;
  final EntityId? entityId;

  UserEntityFilter({this.userId, this.entityId});

  @override
  List<Object?> get props => [userId, entityId];
}

// class UserEntityRecordsDataSource implements UserEntityDataSource<RecordDocumentId, String> {
//   @override
//   Future<void> clear({UserEntityFilter? scope}) {
//     // TODO: implement clear
//     throw UnimplementedError();
//   }

//   @override
//   Future<void> clearAll() {
//     // TODO: implement clearAll
//     throw UnimplementedError();
//   }

//   @override
//   Future<void> delete(RecordDocumentId key, {UserEntityFilter? scope}) {
//     // TODO: implement delete
//     throw UnimplementedError();
//   }

//   @override
//   Future<void> deleteMany(Iterable<RecordDocumentId> keys, {UserEntityFilter? scope}) {
//     // TODO: implement deleteMany
//     throw UnimplementedError();
//   }

//   @override
//   Future<bool> exists(RecordDocumentId key, {UserEntityFilter? scope}) {
//     // TODO: implement exists
//     throw UnimplementedError();
//   }

//   @override
//   Future<String?> find(RecordDocumentId key, {UserEntityFilter? scope}) {
//     // TODO: implement find
//     throw UnimplementedError();
//   }

//   @override
//   Future<List<String>> findAll({UserEntityFilter? scope}) {
//     // TODO: implement findAll
//     throw UnimplementedError();
//   }

//   @override
//   Future<List<String>> findMany(Iterable<RecordDocumentId> keys, {UserEntityFilter? scope}) {
//     // TODO: implement findMany
//     throw UnimplementedError();
//   }

//   @override
//   Future<void> put(RecordDocumentId key, String value, {UserEntityFilter? scope}) {
//     // TODO: implement put
//     throw UnimplementedError();
//   }

//   @override
//   Future<void> putBulk(Map<RecordDocumentId, String> values, {UserEntityFilter? scope}) {
//     // TODO: implement putBulk
//     throw UnimplementedError();
//   }
// }
