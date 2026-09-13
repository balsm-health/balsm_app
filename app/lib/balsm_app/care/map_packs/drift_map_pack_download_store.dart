import 'package:core/core.dart';

import 'map_pack_download_row.dart';
import 'map_pack_download_store.dart';

/// [MapPackDownloadStore] over the `map_pack_download` and `map_pack_name`
/// tables in [AppDatabase]. Raw SQL, matching every other DAO in this
/// database (see the schema consts in `app_database.dart`) — not generated
/// drift `Table` classes.
class DriftMapPackDownloadStore implements MapPackDownloadStore {
  const DriftMapPackDownloadStore(this._db);

  final AppDatabase _db;

  @override
  Future<List<MapPackDownloadRow>> all() async {
    final rows = await _db
        .customSelect(
          'SELECT governorate_id, kind, version, sha256, size_bytes, local_path, downloaded_at '
          'FROM map_pack_download',
        )
        .get();
    return rows.map(_toRow).toList(growable: false);
  }

  @override
  Future<MapPackDownloadRow?> find(String governorateId, MapPackKind kind) async {
    final rows = await _db.customSelect(
      'SELECT governorate_id, kind, version, sha256, size_bytes, local_path, downloaded_at '
      'FROM map_pack_download WHERE governorate_id = ? AND kind = ? LIMIT 1',
      variables: [Variable.withString(governorateId), Variable.withString(kind.wire)],
    ).get();
    return rows.isEmpty ? null : _toRow(rows.first);
  }

  @override
  Future<void> upsert(MapPackDownloadRow row) => _db.customInsert(
        'INSERT OR REPLACE INTO map_pack_download '
        '(governorate_id, kind, version, sha256, size_bytes, local_path, downloaded_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        variables: [
          Variable.withString(row.governorateId),
          Variable.withString(row.kind.wire),
          Variable.withString(row.version),
          Variable.withString(row.sha256),
          Variable.withInt(row.sizeBytes),
          Variable.withString(row.localPath),
          Variable.withInt(row.downloadedAt.toUtc().millisecondsSinceEpoch),
        ],
      );

  @override
  Future<void> deleteGovernorate(String governorateId) => _db.customStatement(
        'DELETE FROM map_pack_download WHERE governorate_id = ?',
        [governorateId],
      );

  @override
  Future<String?> nameFor(String governorateId, String lang) async {
    final rows = await _db.customSelect(
      'SELECT name FROM map_pack_name WHERE governorate_id = ? AND lang = ? LIMIT 1',
      variables: [Variable.withString(governorateId), Variable.withString(lang)],
    ).get();
    return rows.isEmpty ? null : rows.first.read<String>('name');
  }

  @override
  Future<void> upsertName(String governorateId, String lang, String name) => _db.customInsert(
        'INSERT OR REPLACE INTO map_pack_name (governorate_id, lang, name) VALUES (?, ?, ?)',
        variables: [Variable.withString(governorateId), Variable.withString(lang), Variable.withString(name)],
      );

  MapPackDownloadRow _toRow(QueryRow r) => MapPackDownloadRow(
        governorateId: r.read<String>('governorate_id'),
        kind: MapPackKind.fromWire(r.read<String>('kind')),
        version: r.read<String>('version'),
        sha256: r.read<String>('sha256'),
        sizeBytes: r.read<int>('size_bytes'),
        localPath: r.read<String>('local_path'),
        downloadedAt: DateTime.fromMillisecondsSinceEpoch(r.read<int>('downloaded_at'), isUtc: true),
      );
}
