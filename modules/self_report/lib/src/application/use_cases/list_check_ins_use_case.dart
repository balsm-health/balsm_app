import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/aggregates/check_in.dart';
import '../ports/check_ins_data_source.dart';
import '../../infrastructure/drift/drift_check_ins_data_source.dart';

/// Reads the active profile's check-in history, newest first.
class ListCheckInsUseCase {
  ListCheckInsUseCase({required this.dao});

  final CheckInsDataSource dao;

  Future<List<CheckIn>> call() => dao.findAll();

  Stream<List<CheckIn>> watch() => dao.watchAll();

  /// Person [profileId]'s check-ins, newest first, live — whichever profile
  /// is active (a family member's trends).
  Stream<List<CheckIn>> watchFor(HealthProfileId profileId) => dao.watchAll(scope: profileId);
}

final listCheckInsUseCaseProvider = Provider<ListCheckInsUseCase>(
  (ref) => ListCheckInsUseCase(dao: ref.watch(checkInsDataSourceProvider)),
);

/// Reactive check-in history for the active profile (empty when signed out).
final checkInHistoryProvider = StreamProvider<List<CheckIn>>((ref) {
  final profileId = ref.watch(currentProfileIdProvider);
  if (profileId == null) return Stream.value(const <CheckIn>[]);
  return ref.watch(listCheckInsUseCaseProvider).watch();
});

/// Person [profileId]'s check-in history, newest first, live. Empty while
/// signed out.
final profileCheckInsProvider = StreamProvider.autoDispose.family<List<CheckIn>, HealthProfileId>((ref, profileId) {
  if (ref.watch(currentUserIdProvider) == null) return Stream.value(const <CheckIn>[]);
  return ref.watch(listCheckInsUseCaseProvider).watchFor(profileId);
});
