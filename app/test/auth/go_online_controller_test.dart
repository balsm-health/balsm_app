import 'dart:io';

import 'package:app/balsm_app/auth/go_online_controller.dart';
import 'package:auth/auth.dart';
import 'package:core/core.dart';
import 'package:disclosure/disclosure.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSignIn extends Mock implements SignInUseCase {}

class _MockOffline extends Mock implements OfflineAccountService {}

class _MockDisclosure extends Mock implements AcceptDisclosureUseCase {}

class _MockFiles extends Mock implements UserFileStore {}

/// In-memory secure store — the controller reads `balsm.user_id` and writes
/// `balsm.pending_merge_target` through it.
class _MemStorage extends SecureStorageWrapper {
  final Map<String, String> data = {};
  @override
  Future<String?> readToken(String key) async => data[key];
  @override
  Future<void> writeToken(String key, String value) async => data[key] = value;
  @override
  Future<void> deleteToken(String key) async => data.remove(key);
}

class _Db extends GeneratedDatabase {
  _Db() : super(NativeDatabase.memory());
  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];
  @override
  int get schemaVersion => 1;
}

Future<List<String?>> owners(GeneratedDatabase db) async =>
    (await db.customSelect('SELECT user_id FROM prescription ORDER BY rowid').get())
        .map((r) => r.read<String?>('user_id'))
        .toList();

void main() {
  late _MockSignIn signIn;
  late _MockOffline offline;
  late _MockDisclosure disclosure;
  late _MockFiles files;
  late _MemStorage storage;
  late EventBus bus;
  late List<AppEvent> events;
  late _Db db;
  late GoOnlineController controller;

  setUpAll(() {
    registerFallbackValue(const DisclosureId.value('x'));
  });

  setUp(() async {
    signIn = _MockSignIn();
    offline = _MockOffline();
    disclosure = _MockDisclosure();
    files = _MockFiles();
    when(() => files.rekeyOwnerFiles(from: any(named: 'from'), to: any(named: 'to'))).thenAnswer((_) async {});
    when(() => files.mergeOwnerFiles(from: any(named: 'from'), to: any(named: 'to'))).thenAnswer((_) async {});
    when(() => files.deleteOwnerFiles(owner: any(named: 'owner'))).thenAnswer((_) async {});
    storage = _MemStorage();
    bus = EventBus();
    events = [];
    bus.events.listen(events.add);
    db = _Db();
    await db.customStatement('CREATE TABLE prescription (id TEXT, user_id TEXT)');
    when(() => offline.markOnline()).thenAnswer((_) async {});
    when(() => offline.clearPlainPassword()).thenAnswer((_) async {});
    when(() => offline.setPendingMerge(any())).thenAnswer((_) async {});
    when(() => disclosure.resync(disclosureId: any(named: 'disclosureId'), version: any(named: 'version')))
        .thenAnswer((_) async => true);
    controller = GoOnlineController(
      signIn: signIn,
      offline: offline,
      disclosure: disclosure,
      db: db,
      files: files,
      storage: storage,
      eventBus: bus,
      countryCode: () => 'EG',
    );
  });

  tearDown(() async {
    bus.dispose();
    await db.close();
  });

  Future<void> stubCreds({required String email, required String password, required String localId}) async {
    when(() => offline.pendingCredentials()).thenAnswer((_) async => (email: email, password: password));
    storage.data['balsm.user_id'] = localId;
    await db.customStatement("INSERT INTO prescription VALUES ('r1', '$localId')");
  }

  // The bus is a broadcast stream: let queued events land before asserting.
  Future<void> flush() => Future<void>.delayed(Duration.zero);

  test('adopted: no re-key, marks online, sets password, clears plaintext, publishes sign-in', () async {
    await stubCreds(email: 'a@b.co', password: 'correct-horse', localId: 'off-1');
    when(() => signIn.goOnline(email: 'a@b.co', code: '123456', clientAccountId: 'off-1'))
        .thenAnswer((_) async => AppResult.success(const GoOnlineAdopted()));
    when(() => signIn.setPassword(password: 'correct-horse')).thenAnswer((_) async => AppResult.success(null));

    final r = await controller.verify(email: 'a@b.co', code: '123456');
    await flush();

    expect(r.value, GoOnlineOutcome.online);
    verify(() => offline.markOnline()).called(1);
    verify(() => offline.clearPlainPassword()).called(1);
    expect(await owners(db), ['off-1']);
    expect(events.whereType<UserSignedIn>().single.userId.value, 'off-1');
    verify(() => disclosure.resync(disclosureId: any(named: 'disclosureId'), version: any(named: 'version'))).called(1);
    verifyNever(() => files.rekeyOwnerFiles(from: any(named: 'from'), to: any(named: 'to')));
    // Flow complete: the pin and the disclosure retry flag are gone.
    expect(storage.data.containsKey('balsm.offline.local_id'), isFalse);
    expect(storage.data.containsKey('balsm.offline.disclosure_pending'), isFalse);
  });

  test('new id: re-keys local rows before publishing sign-in', () async {
    await stubCreds(email: 'a@b.co', password: 'correct-horse', localId: 'off-1');
    when(() => signIn.goOnline(
            email: any(named: 'email'), code: any(named: 'code'), clientAccountId: any(named: 'clientAccountId')))
        .thenAnswer((_) async => AppResult.success(const GoOnlineNewId('srv-9')));
    when(() => signIn.setPassword(password: any(named: 'password'))).thenAnswer((_) async => AppResult.success(null));

    // Record the order: the files must move before anyone hears of the new id.
    final order = <String>[];
    when(() => files.rekeyOwnerFiles(from: any(named: 'from'), to: any(named: 'to')))
        .thenAnswer((_) async => order.add('files'));
    bus.on<UserSignedIn>().listen((_) => order.add('signedIn'));

    await controller.verify(email: 'a@b.co', code: '123456');
    await flush();

    expect(await owners(db), ['srv-9']);
    expect(events.whereType<UserSignedIn>().single.userId.value, 'srv-9');
    verify(() => files.rekeyOwnerFiles(from: 'off-1', to: 'srv-9')).called(1);
    expect(order, ['files', 'signedIn']);
    expect(storage.data.containsKey('balsm.offline.local_id'), isFalse);
  });

  test('retry after a failed re-key uses the pinned offline id, not the server id', () async {
    await stubCreds(email: 'a@b.co', password: 'correct-horse', localId: 'off-1');
    // goOnline persists the session, overwriting balsm.user_id — as the real one does.
    when(() => signIn.goOnline(
        email: any(named: 'email'),
        code: any(named: 'code'),
        clientAccountId: any(named: 'clientAccountId'))).thenAnswer((_) async {
      storage.data['balsm.user_id'] = 'srv-9';
      return AppResult.success(const GoOnlineNewId('srv-9'));
    });
    when(() => signIn.setPassword(password: any(named: 'password'))).thenAnswer((_) async => AppResult.success(null));
    await db
        .customStatement("CREATE TRIGGER boom BEFORE UPDATE ON prescription BEGIN SELECT RAISE(ABORT, 'boom'); END");

    final first = await controller.verify(email: 'a@b.co', code: '123456');
    expect(first.isFailure, isTrue);
    expect(await owners(db), ['off-1']);
    expect(storage.data['balsm.offline.local_id'], 'off-1');
    verifyNever(() => offline.markOnline());

    await db.customStatement('DROP TRIGGER boom');
    final second = await controller.verify(email: 'a@b.co', code: '654321');
    await flush();

    expect(second.value, GoOnlineOutcome.online);
    verify(() => signIn.goOnline(email: 'a@b.co', code: '654321', clientAccountId: 'off-1')).called(1);
    expect(await owners(db), ['srv-9']);
    expect(events.whereType<UserSignedIn>().single.userId.value, 'srv-9');
  });

  test('a failed file move is a failure and leaves the pin on the offline id', () async {
    await stubCreds(email: 'a@b.co', password: 'correct-horse', localId: 'off-1');
    when(() => signIn.goOnline(
            email: any(named: 'email'), code: any(named: 'code'), clientAccountId: any(named: 'clientAccountId')))
        .thenAnswer((_) async => AppResult.success(const GoOnlineNewId('srv-9')));
    when(() => files.rekeyOwnerFiles(from: any(named: 'from'), to: any(named: 'to')))
        .thenThrow(StateError('target owner already has files'));

    final r = await controller.verify(email: 'a@b.co', code: '123456');
    await flush();

    expect(r.isFailure, isTrue);
    expect(storage.data['balsm.offline.local_id'], 'off-1');
    verifyNever(() => offline.markOnline());
    expect(events.whereType<UserSignedIn>(), isEmpty);
  });

  test('SetPassword failure keeps plaintext for retry; user is still online', () async {
    await stubCreds(email: 'a@b.co', password: 'correct-horse', localId: 'off-1');
    when(() => signIn.goOnline(
            email: any(named: 'email'), code: any(named: 'code'), clientAccountId: any(named: 'clientAccountId')))
        .thenAnswer((_) async => AppResult.success(const GoOnlineAdopted()));
    when(() => signIn.setPassword(password: any(named: 'password')))
        .thenAnswer((_) async => AppResult.failure(const NetworkFailure()));

    final r = await controller.verify(email: 'a@b.co', code: '123456');

    expect(r.value, GoOnlineOutcome.online);
    verifyNever(() => offline.clearPlainPassword());
  });

  test('existing account: sets pending merge, no re-key, no sign-in event', () async {
    await stubCreds(email: 'a@b.co', password: 'correct-horse', localId: 'off-1');
    when(() => signIn.goOnline(
            email: any(named: 'email'), code: any(named: 'code'), clientAccountId: any(named: 'clientAccountId')))
        .thenAnswer((_) async => AppResult.success(const GoOnlineExistingAccount('srv-1')));

    final r = await controller.verify(email: 'a@b.co', code: '123456');
    await flush();

    expect(r.value, GoOnlineOutcome.needsMergeChoice);
    verify(() => offline.setPendingMerge(true)).called(1);
    verifyNever(() => offline.markOnline());
    expect(await owners(db), ['off-1']);
    expect(events.whereType<UserSignedIn>(), isEmpty);
    expect(controller.pendingTargetId, 'srv-1');
    expect(storage.data['balsm.pending_merge_target'], 'srv-1');
    // The merge screen needs the device's own id; it stays pinned.
    expect(storage.data['balsm.offline.local_id'], 'off-1');
  });

  test('a failed disclosure resync is flagged, and retried at launch', () async {
    await stubCreds(email: 'a@b.co', password: 'correct-horse', localId: 'off-1');
    when(() => signIn.goOnline(
            email: any(named: 'email'), code: any(named: 'code'), clientAccountId: any(named: 'clientAccountId')))
        .thenAnswer((_) async => AppResult.success(const GoOnlineAdopted()));
    when(() => signIn.setPassword(password: any(named: 'password'))).thenAnswer((_) async => AppResult.success(null));
    when(() => disclosure.resync(disclosureId: any(named: 'disclosureId'), version: any(named: 'version')))
        .thenAnswer((_) async => false);

    await controller.verify(email: 'a@b.co', code: '123456');
    expect(storage.data['balsm.offline.disclosure_pending'], 'true');

    when(() => offline.pendingCredentials()).thenAnswer((_) async => null);
    when(() => disclosure.resync(disclosureId: any(named: 'disclosureId'), version: any(named: 'version')))
        .thenAnswer((_) async => true);
    await controller.retryPending();
    expect(storage.data.containsKey('balsm.offline.disclosure_pending'), isFalse);
  });

  test('retryPending retries the password and swallows keychain errors', () async {
    when(() => offline.pendingCredentials()).thenThrow(Exception('keychain'));
    await expectLater(controller.retryPending(), completes);

    when(() => offline.pendingCredentials()).thenAnswer((_) async => (email: '', password: 'correct-horse'));
    when(() => signIn.setPassword(password: 'correct-horse')).thenAnswer((_) async => AppResult.success(null));
    await controller.retryPending();
    verify(() => offline.clearPlainPassword()).called(1);
    verifyNever(() => disclosure.resync(disclosureId: any(named: 'disclosureId'), version: any(named: 'version')));
  });

  test('verify failure surfaces the failure and changes nothing', () async {
    await stubCreds(email: 'a@b.co', password: 'correct-horse', localId: 'off-1');
    when(() => signIn.goOnline(
            email: any(named: 'email'), code: any(named: 'code'), clientAccountId: any(named: 'clientAccountId')))
        .thenAnswer((_) async => AppResult.failure(const NetworkFailure('bad code')));

    final r = await controller.verify(email: 'a@b.co', code: '000000');
    await flush();

    expect(r.isFailure, isTrue);
    verifyNever(() => offline.markOnline());
    expect(events.whereType<UserSignedIn>(), isEmpty);
  });

  test('lockout is a failure and records when it ends', () async {
    await stubCreds(email: 'a@b.co', password: 'correct-horse', localId: 'off-1');
    final until = DateTime.now().toUtc().add(const Duration(minutes: 5));
    when(() => signIn.goOnline(
            email: any(named: 'email'), code: any(named: 'code'), clientAccountId: any(named: 'clientAccountId')))
        .thenAnswer((_) async => AppResult.success(GoOnlineLockout(LockedOut(until: until, identifier: 'x'))));

    final r = await controller.verify(email: 'a@b.co', code: '000000');

    expect(r.isFailure, isTrue);
    expect(controller.lockedUntil, until);
    verifyNever(() => offline.markOnline());
  });

  test('sendCode asks for a continue code with the current country', () async {
    when(() => signIn.requestContinueOtp('a@b.co', 'EG')).thenAnswer((_) async => AppResult.success(null));
    final r = await controller.sendCode('a@b.co');
    expect(r.isSuccess, isTrue);
    verify(() => signIn.requestContinueOtp('a@b.co', 'EG')).called(1);
  });

  test('finishPasswordIfPending is a no-op with nothing pending', () async {
    when(() => offline.pendingCredentials()).thenAnswer((_) async => null);
    await controller.finishPasswordIfPending();
    verifyNever(() => signIn.setPassword(password: any(named: 'password')));
  });

  group('merge or discard', () {
    /// The state a GoOnlineExistingAccount verify leaves behind: goOnline has
    /// already written the existing account's id to balsm.user_id; the
    /// device's own id is pinned; the target is persisted.
    Future<void> seedPendingMerge({required String localId, required String target}) async {
      storage.data['balsm.user_id'] = target;
      storage.data['balsm.offline.local_id'] = localId;
      storage.data['balsm.pending_merge_target'] = target;
      storage.data['balsm.offline.email'] = 'a@b.co';
      await db.customStatement("INSERT INTO prescription VALUES ('r1', '$localId'), ('r2', '$target')");
      await db.customStatement('CREATE TABLE sync_outbox (id INTEGER PRIMARY KEY, user_id TEXT)');
      await db.customStatement("INSERT INTO sync_outbox (user_id) VALUES ('$localId')");
      when(() => offline.pendingCredentials()).thenAnswer((_) async => (email: 'a@b.co', password: 'offline-pw'));
    }

    Future<List<String?>> outboxOwners() async => (await db.customSelect('SELECT user_id FROM sync_outbox').get())
        .map((r) => r.read<String?>('user_id'))
        .toList();

    void expectCleared() {
      expect(storage.data.containsKey('balsm.offline.local_id'), isFalse);
      expect(storage.data.containsKey('balsm.pending_merge_target'), isFalse);
      verify(() => offline.setPendingMerge(false)).called(1);
      expect(storage.data['balsm.user_id'], 'srv-1');
    }

    test('merge: local rows move to the existing account, outbox dropped, offline password discarded', () async {
      await seedPendingMerge(localId: 'off-1', target: 'srv-1');
      final r = await controller.merge();
      await flush();

      expect(r.isSuccess, isTrue);
      expect(await owners(db), ['srv-1', 'srv-1']);
      expect(await outboxOwners(), isEmpty);
      verify(() => files.mergeOwnerFiles(from: 'off-1', to: 'srv-1')).called(1);
      verify(() => offline.clearPlainPassword()).called(1);
      verify(() => offline.markOnline()).called(1);
      verifyNever(() => signIn.setPassword(password: any(named: 'password')));
      final signedIn = events.whereType<UserSignedIn>().single;
      expect(signedIn.userId.value, 'srv-1');
      expect(signedIn.provider, 'email');
      verify(() => disclosure.resync(disclosureId: any(named: 'disclosureId'), version: any(named: 'version')))
          .called(1);
      expect(storage.data.containsKey('balsm.offline.disclosure_pending'), isFalse);
      expectCleared();
    });

    test('merge: a failed disclosure resync is flagged for the launch retry', () async {
      await seedPendingMerge(localId: 'off-1', target: 'srv-1');
      when(() => disclosure.resync(disclosureId: any(named: 'disclosureId'), version: any(named: 'version')))
          .thenAnswer((_) async => false);
      await controller.merge();
      expect(storage.data['balsm.offline.disclosure_pending'], 'true');
    });

    test('merge: a storage failure changes nothing else and can be retried', () async {
      await seedPendingMerge(localId: 'off-1', target: 'srv-1');
      when(() => files.mergeOwnerFiles(from: any(named: 'from'), to: any(named: 'to'))).thenThrow(StateError('disk'));

      final first = await controller.merge();
      await flush();
      expect(first.isFailure, isTrue);
      verifyNever(() => offline.markOnline());
      verifyNever(() => offline.setPendingMerge(false));
      expect(events.whereType<UserSignedIn>(), isEmpty);
      expect(storage.data['balsm.offline.local_id'], 'off-1');
      expect(storage.data['balsm.pending_merge_target'], 'srv-1');

      when(() => files.mergeOwnerFiles(from: any(named: 'from'), to: any(named: 'to'))).thenAnswer((_) async {});
      final second = await controller.merge();
      await flush();
      expect(second.isSuccess, isTrue);
      expect(await owners(db), ['srv-1', 'srv-1']);
      expectCleared();
    });

    test('discard: local rows and files are gone, user signed in to existing account', () async {
      await seedPendingMerge(localId: 'off-1', target: 'srv-1');
      final r = await controller.discard();
      await flush();

      expect(r.isSuccess, isTrue);
      expect(await owners(db), ['srv-1']);
      expect(await outboxOwners(), isEmpty);
      verify(() => files.deleteOwnerFiles(owner: 'off-1')).called(1);
      verify(() => offline.clearPlainPassword()).called(1);
      verify(() => offline.markOnline()).called(1);
      verifyNever(() => signIn.setPassword(password: any(named: 'password')));
      expect(events.whereType<UserSignedIn>().single.userId.value, 'srv-1');
      expectCleared();
    });

    test('discard: re-running after a crash part-way finishes the job', () async {
      await seedPendingMerge(localId: 'off-1', target: 'srv-1');
      when(() => files.deleteOwnerFiles(owner: any(named: 'owner'))).thenThrow(const FileSystemException('x'));
      expect((await controller.discard()).isFailure, isTrue);
      verifyNever(() => offline.markOnline());

      when(() => files.deleteOwnerFiles(owner: any(named: 'owner'))).thenAnswer((_) async {});
      expect((await controller.discard()).isSuccess, isTrue);
      await flush();
      expect(await owners(db), ['srv-1']);
      expect(events.whereType<UserSignedIn>().single.userId.value, 'srv-1');
    });

    test('without a pinned device id or target, both refuse and touch nothing', () async {
      await seedPendingMerge(localId: 'off-1', target: 'srv-1');
      storage.data.remove('balsm.pending_merge_target');
      expect((await controller.merge()).isFailure, isTrue);
      expect((await controller.discard()).isFailure, isTrue);
      expect(await owners(db), ['off-1', 'srv-1']);

      storage.data['balsm.pending_merge_target'] = 'srv-1';
      storage.data.remove('balsm.offline.local_id');
      expect((await controller.discard()).isFailure, isTrue);
      expect(await owners(db), ['off-1', 'srv-1']);
    });

    test('discard refuses when the device id is the target (would delete the account itself)', () async {
      await seedPendingMerge(localId: 'srv-1', target: 'srv-1');
      expect((await controller.discard()).isFailure, isTrue);
      expect(await owners(db), ['srv-1', 'srv-1']);
    });
  });
}
