import 'package:dio/dio.dart' show CancelToken;

import 'requests.dart';
import 'responses.dart';

/// The patient's own care team, mirrored to the Balsm cloud (FR-500).
///
/// This carries PHI over TLS to the trusted .NET API — unlike [CareDirectoryApi],
/// which serves Balsm-owned NON-PHI reference data about public places.
abstract class CareTeamApi {
  /// GET /care-team/providers — rows changed since [since], tombstones included.
  /// Null [since] pulls the whole roster.
  Future<List<CareProviderResponse>> pull({
    required String healthProfileId,
    DateTime? since,
    CancelToken? cancelToken,
  });

  /// POST /care-team/providers — create or overwrite, idempotent on id.
  Future<void> upsert(UpsertCareProviderRequest request, {CancelToken? cancelToken});

  /// DELETE /care-team/providers/{id} — tombstone. A 404 is treated as success:
  /// the row is already gone, which is the outcome the caller wanted.
  Future<void> delete(String id, {CancelToken? cancelToken});
}
