// Last-writer-wins for aggregates; union+dedup for dose event streams.
// Per FR-009d, FR-009e.

class ConflictResolver {
  static T mergeAggregate<T extends _Updatable>(T existing, T incoming) {
    return existing.updatedAt.isAfter(incoming.updatedAt) ? existing : incoming;
  }

  static List<DoseEventRecord> mergeDoseStreams(
    List<DoseEventRecord> existing,
    List<DoseEventRecord> incoming,
  ) {
    final merged = <DoseEventRecord>[...existing];
    for (final event in incoming) {
      final isDuplicate = merged.any((e) =>
          e.medicationId == event.medicationId &&
          e.outcome == event.outcome &&
          (e.scheduledAt.difference(event.scheduledAt).abs() <= const Duration(minutes: 5)));
      if (!isDuplicate) merged.add(event);
    }
    merged.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return merged;
  }
}

abstract class _Updatable {
  DateTime get updatedAt;
}

class DoseEventRecord {
  const DoseEventRecord({
    required this.medicationId,
    required this.scheduledAt,
    required this.outcome,
    this.isDuplicate = false,
  });

  final String medicationId;
  final DateTime scheduledAt;
  final String outcome;
  final bool isDuplicate;
}
