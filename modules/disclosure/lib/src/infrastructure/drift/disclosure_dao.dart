import 'package:core/core.dart';
import 'package:drift/drift.dart';

import '../../domain/aggregates/disclosure_acceptance.dart';
import '../../domain/value_objects/ids.dart';

/// Drift DAO for on-device persistence of disclosure acceptances.
///
/// Writes to the raw-SQL `disclosure_acceptance` table declared in
/// [AppDatabase]'s on-device schema, using the same customInsert/customSelect
/// pattern as the profile/medications DAOs. Acceptance rows are PHI-free.
class DisclosureDao {
  DisclosureDao(this._db);

  final AppDatabase _db;

  /// Persists [acceptance] on-device. Idempotent per (disclosure, version):
  /// re-accepting the same disclosure version refreshes the stored context.
  ///
  /// Throws a drift exception (wrapped by callers as [StorageFailure]) when the
  /// write fails.
  Future<void> insert(DisclosureAcceptance acceptance) async {
    await _db.customInsert(
      '''
      INSERT INTO disclosure_acceptance
        (id, disclosure_id, version, country_code,
         supervisory_authority_name, preferred_language, accepted_at)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(disclosure_id, version) DO UPDATE SET
        country_code = excluded.country_code,
        supervisory_authority_name = excluded.supervisory_authority_name,
        preferred_language = excluded.preferred_language,
        accepted_at = excluded.accepted_at
      ''',
      variables: [
        Variable.withString(UniqueId.uuid().value),
        Variable.withString(acceptance.disclosureId.value),
        Variable.withString(acceptance.version),
        Variable.withString(acceptance.countryCodeAtAccept),
        Variable.withString(acceptance.supervisoryAuthorityNameAtAccept),
        Variable.withString(acceptance.preferredLanguageAtAccept),
        Variable.withInt(acceptance.acceptedAt.millisecondsSinceEpoch),
      ],
    );
  }

  /// Returns a live stream of the stored acceptance for the given
  /// [disclosureId] and [version].  Emits `null` when no record exists.
  Stream<DisclosureAcceptance?> watchAcceptance(
    DisclosureId disclosureId,
    String version,
  ) {
    return _db
        .customSelect(
          'SELECT * FROM disclosure_acceptance '
          'WHERE disclosure_id = ? AND version = ? '
          'ORDER BY accepted_at DESC LIMIT 1',
          variables: [
            Variable.withString(disclosureId.value),
            Variable.withString(version),
          ],
          readsFrom: {},
        )
        .watch()
        .map((rows) => rows.isEmpty ? null : _hydrate(rows.first));
  }

  DisclosureAcceptance _hydrate(QueryRow row) => DisclosureAcceptance(
        disclosureId: DisclosureId.value(row.read<String>('disclosure_id')),
        version: row.read<String>('version'),
        countryCodeAtAccept: row.read<String>('country_code'),
        supervisoryAuthorityNameAtAccept:
            row.read<String>('supervisory_authority_name'),
        preferredLanguageAtAccept: row.read<String>('preferred_language'),
        acceptedAt: DateTime.fromMillisecondsSinceEpoch(
          row.read<int>('accepted_at'),
          isUtc: true,
        ),
      );
}
