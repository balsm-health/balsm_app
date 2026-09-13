import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a snapshot never carries cache rows', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await DriftCacheStore(db).write('account', 'u1', '{"handle":"sara"}');

    final snapshot = await SnapshotService(db).export();
    final tables = (snapshot['tables'] as Map).cast<String, dynamic>();

    expect(tables.containsKey('cache_entry'), isFalse,
        reason: 'cache_entry must stay out of SnapshotService._tables — '
            'cache is not PHI and must not travel in a backup');
  });
}
