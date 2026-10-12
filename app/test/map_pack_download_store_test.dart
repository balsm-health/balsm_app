import 'package:app/balsm_app/care/map_packs/drift_map_pack_download_store.dart';
import 'package:app/balsm_app/care/map_packs/map_pack_download_row.dart';
import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftMapPackDownloadStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftMapPackDownloadStore(db);
  });
  tearDown(() => db.close());

  MapPackDownloadRow row({String governorateId = 'cairo', MapPackKind kind = MapPackKind.basemap}) =>
      MapPackDownloadRow(
        governorateId: governorateId,
        kind: kind,
        version: '20260913',
        sha256: '0' * 64,
        sizeBytes: 1000,
        localPath: '/tmp/$governorateId-${kind.wire}.bin',
        downloadedAt: DateTime.utc(2026, 9, 13),
      );

  test('upsert then find round-trips', () async {
    await store.upsert(row());
    final found = await store.find('cairo', MapPackKind.basemap);
    expect(found, isNotNull);
    expect(found!.version, '20260913');
    expect(found.sizeBytes, 1000);
  });

  test('find returns null for a missing (governorate, kind) pair', () async {
    expect(await store.find('cairo', MapPackKind.places), isNull);
  });

  test('upsert with the same key replaces in place', () async {
    await store.upsert(row());
    await store.upsert(MapPackDownloadRow(
      governorateId: 'cairo',
      kind: MapPackKind.basemap,
      version: '20260920',
      sha256: '0' * 64,
      sizeBytes: 1000,
      localPath: '/tmp/cairo-basemap.bin',
      downloadedAt: DateTime.utc(2026, 9, 13),
    ));
    final all = await store.all();
    expect(all, hasLength(1));
    expect(all.single.version, '20260920');
  });

  test('all() returns rows across governorates and kinds', () async {
    await store.upsert(row());
    await store.upsert(row(kind: MapPackKind.places));
    await store.upsert(row(governorateId: 'giza'));
    expect(await store.all(), hasLength(3));
  });

  test('deleteGovernorate removes both kinds, leaves others', () async {
    await store.upsert(row());
    await store.upsert(row(kind: MapPackKind.places));
    await store.upsert(row(governorateId: 'giza'));

    await store.deleteGovernorate('cairo');

    final all = await store.all();
    expect(all, hasLength(1));
    expect(all.single.governorateId, 'giza');
  });

  test('name is null until upserted, then round-trips per language', () async {
    expect(await store.nameFor('cairo', 'en'), isNull);

    await store.upsertName('cairo', 'en', 'Cairo');
    expect(await store.nameFor('cairo', 'en'), 'Cairo');
    expect(await store.nameFor('cairo', 'ar'), isNull);

    await store.upsertName('cairo', 'ar', 'القاهرة');
    expect(await store.nameFor('cairo', 'en'), 'Cairo'); // untouched by the ar upsert
    expect(await store.nameFor('cairo', 'ar'), 'القاهرة');
  });
}
