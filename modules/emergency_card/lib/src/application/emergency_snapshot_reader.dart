import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/aggregates/emergency_card_snapshot.dart';

/// Reads the current patient's [EmergencyCardSnapshot] from the on-device
/// HealthProfile (PHI). The implementation lives in app wiring and is backed by
/// the `profile` package's read repository / DriftProfileDataSource; this keeps the
/// emergency_card bounded context decoupled from profile internals.
///
/// The returned snapshot contains PHI and MUST NOT be logged or sent to Sentry.
abstract class EmergencySnapshotReader {
  Future<EmergencyCardSnapshot?> readSnapshot();
}

/// Override this in the app `ProviderScope` with a concrete implementation that
/// adapts the `profile` package's read repository into an
/// [EmergencySnapshotReader].
final emergencySnapshotReaderProvider = Provider<EmergencySnapshotReader>((ref) {
  throw UnimplementedError(
    'Override emergencySnapshotReaderProvider in the app ProviderScope '
    'with a profile-backed EmergencySnapshotReader.',
  );
});
