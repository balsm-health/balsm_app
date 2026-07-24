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
