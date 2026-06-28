import 'dart:async';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory snapshot — no DB needed.
class _FakeSnapshot implements SnapshotPort {
  Map<String, dynamic>? imported;
  @override
  Future<Map<String, dynamic>> export() async => {
        'schemaVersion': 1,
        'tables': {
          'health_profile': [
            {'id': 'p1', 'user_id': 'u1', 'blood_type': 'B+', 'updated_at': '2026-01-01T00:00:00Z'}
          ],
        },
      };
  @override
  Future<void> import(Map<String, dynamic> s) async => imported = s;
}

/// Records uploads; can be told to fail (simulating offline).
class _RecordingAdapter implements BackupAdapter {
  final store = <String, Uint8List>{};
  bool fail = false;
  @override
  Future<void> upload(Uint8List blob, String key) async {
    if (fail) throw Exception('offline');
    store[key] = blob;
  }

  @override
  Future<Uint8List?> download(String key) async => store[key];
  @override
  Future<bool> hasBackup(String key) async => store.containsKey(key);
}

void main() {
  late EventBus bus;
  late SyncStatusNotifier status;
  late FakeSecureStorage storage;
  late _RecordingAdapter adapter;
  late _FakeSnapshot snapshot;
  late StreamController<bool> online;

  BackupService build() => BackupService(
        bus: bus,
        snapshot: snapshot,
        adapter: adapter,
        storage: storage,
        status: status,
        userId: 'u1',
        onlineStream: online.stream,
      );

  setUp(() {
    bus = EventBus();
    status = SyncStatusNotifier();
    storage = FakeSecureStorage();
    adapter = _RecordingAdapter();
    snapshot = _FakeSnapshot();
    online = StreamController<bool>.broadcast();
  });

  test('provision generates a recovery code once', () async {
    final svc = build();
    final code = await svc.provisionIfNeeded();
    expect(code, isNotNull);
    expect(await svc.isProvisioned(), isTrue);
    expect(await svc.provisionIfNeeded(), isNull); // idempotent
    svc.dispose();
  });

  test('flush snapshots → encrypts → uploads; status synced', () async {
    final svc = build();
    await svc.provisionIfNeeded();
    await svc.flush();
    expect(adapter.store['balsm-backup-u1.aes'], isNotNull);
    expect(status.state.state, SyncState.synced);
    // Uploaded blob is a valid BLSM blob, not plaintext.
    final blob = adapter.store['balsm-backup-u1.aes']!;
    expect(String.fromCharCodes(blob.sublist(0, 4)), 'BLSM');
    svc.dispose();
  });

  test('critical event triggers a flush via the bus', () async {
    final svc = build();
    await svc.provisionIfNeeded();
    bus.publish(_FlushEvent());
    await _until(() => adapter.store.isNotEmpty); // flush runs Argon2id (slow)
    expect(adapter.store.isNotEmpty, isTrue);
    svc.dispose();
  });

  test('offline upload marks dirty + offline, then retries on reconnect', () async {
    final svc = build();
    await svc.provisionIfNeeded();
    adapter.fail = true;
    await svc.flush();
    expect(status.state.state, SyncState.offline);
    expect(await storage.readToken('balsm.backup.dirty'), '1');
    expect(adapter.store.isEmpty, isTrue);

    // Reconnect → auto-retry succeeds.
    adapter.fail = false;
    online.add(true);
    await _until(() => adapter.store.isNotEmpty);
    expect(adapter.store.isNotEmpty, isTrue);
    expect(status.state.state, SyncState.synced);
    expect(await storage.readToken('balsm.backup.dirty'), isNull);
    svc.dispose();
  });

  test('revealCode returns the stored code; rotate invalidates the old one', () async {
    final svc = build();
    final original = (await svc.provisionIfNeeded())!;
    expect(await svc.revealCode(), original);
    await svc.flush();

    final rotated = await svc.rotate();
    expect(rotated, isNot(original));
    expect(await svc.revealCode(), rotated);

    // Old code can no longer decrypt the (re-uploaded) blob.
    final restore = RestoreService(
      adapter: adapter, snapshot: _FakeSnapshot(), storage: FakeSecureStorage(), userId: 'u1');
    expect(() => restore.restore(original), throwsA(isA<BackupDecryptException>()));
    await restore.restore(rotated); // new code works
    svc.dispose();
  });

  test('restore downloads + decrypts + imports with the recovery code', () async {
    final svc = build();
    final code = (await svc.provisionIfNeeded())!;
    await svc.flush(); // produces a blob in the shared adapter

    // New device: fresh storage + snapshot, same cloud adapter.
    final freshSnapshot = _FakeSnapshot();
    final restore = RestoreService(
      adapter: adapter,
      snapshot: freshSnapshot,
      storage: FakeSecureStorage(),
      userId: 'u1',
    );
    expect(await restore.hasBackup(), isTrue);
    await restore.restore(code);
    expect(freshSnapshot.imported, isNotNull);
    expect(freshSnapshot.imported!['tables'], isNotNull);
    svc.dispose();
  });
}

/// Polls [cond] until true or a timeout (handles fire-and-forget async flush).
Future<void> _until(bool Function() cond, {Duration timeout = const Duration(seconds: 5)}) async {
  final deadline = DateTime.now().add(timeout);
  while (!cond() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
}

class _FlushEvent extends AppEvent {
  @override
  String get eventName => 'backup_flush_requested';
  @override
  Map<String, dynamic> toJson() => {};
}
