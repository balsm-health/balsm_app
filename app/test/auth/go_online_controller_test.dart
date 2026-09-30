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
  });

  test('new id: re-keys local rows before publishing sign-in', () async {
    await stubCreds(email: 'a@b.co', password: 'correct-horse', localId: 'off-1');
    when(() => signIn.goOnline(
            email: any(named: 'email'), code: any(named: 'code'), clientAccountId: any(named: 'clientAccountId')))
        .thenAnswer((_) async => AppResult.success(const GoOnlineNewId('srv-9')));
    when(() => signIn.setPassword(password: any(named: 'password'))).thenAnswer((_) async => AppResult.success(null));

    await controller.verify(email: 'a@b.co', code: '123456');
    await flush();

    expect(await owners(db), ['srv-9']);
    expect(events.whereType<UserSignedIn>().single.userId.value, 'srv-9');
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
}
