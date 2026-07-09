import 'package:core/core.dart';
import '../../domain/aggregates/disclosure_acceptance.dart';
import '../../domain/value_objects/ids.dart';

/// Drift DAO stub for disclosure_acceptance persistence.
///
/// Tables are defined in AppDatabase (schema to be added in migration M002).
/// This stub compiles against core AppDatabase and provides the necessary
/// method signatures; actual table definitions will be wired when the schema
/// migration is authored.
class DisclosureDao {
  DisclosureDao(this._db);

  final AppDatabase _db;

  /// Persists [acceptance] on-device.
  ///
  /// Throws [StorageFailure]-wrapped exception if the write fails.
  Future<void> insert(DisclosureAcceptance acceptance) async {
    // TODO(M002): replace with generated Drift insertable once
    // DisclosureAcceptances table is declared in AppDatabase.
    // For now, serialize to JSON and store via a key-value fallback.
    throw UnimplementedError(
      'DisclosureDao.insert — awaiting schema migration M002',
    );
  }

  /// Returns a live stream of the stored acceptance for the given
  /// [disclosureId] and [version].  Emits `null` when no record exists.
  Stream<DisclosureAcceptance?> watchAcceptance(
    DisclosureId disclosureId,
    String version,
  ) {
    // TODO(M002): replace with generated Drift watch query.
    throw UnimplementedError(
      'DisclosureDao.watchAcceptance — awaiting schema migration M002',
    );
  }
}
