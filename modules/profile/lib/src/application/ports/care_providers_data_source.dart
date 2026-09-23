import 'package:core/core.dart';

import '../../domain/entities/care_provider.dart';
import '../../domain/value_objects/ids.dart';

/// Persistence port for the patient's care team.
///
/// Its own source rather than more `add*/remove*` methods on
/// [HealthProfilesDataSource]: a care provider is a different key/value pair
/// from a health profile, so it gets the generic contract in its own right —
/// `put` (insert or update), `delete`, `findAll`, `watchAll` — exactly as
/// medications and check-ins do. The caller mints the id, so there is no
/// `add`-returns-an-id special case and re-`put`ting the same id is an edit.
///
/// Scope is the health profile, matching the `health_profile_id` column: who
/// treats a patient is PHI about the SUBJECT, not the account that recorded
/// it, so a dependant's care team stays in its own partition.
///
/// The care team is deliberately not part of the [HealthProfile] aggregate:
/// it is a list the care-team screen watches on its own, and hydrating it
/// into every profile read would cost every caller a join it does not use.
abstract class CareProvidersDataSource extends ProfileDataSource<CareProviderId, CareProvider>
    implements WatchableScopedDataSource<CareProviderId, CareProvider, HealthProfileId> {
  /// Vault-relative paths of the files attached to [providerId], oldest first.
  ///
  /// Attachments are a SET of paths, not keyed records — there is no id to
  /// address one by, and `put(path, path)` would be a key/value pair in name
  /// only. So they keep a narrow surface here rather than a forced
  /// [ScopedDataSource]; the verbs still follow the base contract so the two
  /// read alike at a call site.
  Future<List<String>> findFiles(CareProviderId providerId);

  /// Emits [providerId]'s file paths and again on every change.
  Stream<List<String>> watchFiles(CareProviderId providerId);

  /// Attaches the vault file at [path]. Idempotent — attaching the same path
  /// twice leaves one row.
  Future<void> putFile(CareProviderId providerId, String path);

  /// Detaches [path]. The bytes in the user file store are not touched.
  Future<void> deleteFile(CareProviderId providerId, String path);
}
