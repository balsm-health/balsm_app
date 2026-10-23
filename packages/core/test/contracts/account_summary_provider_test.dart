import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The account summary is what Home, Profile and the account switcher show as
/// "who is signed in". It must follow the session: sign out and register a new
/// account, and the app has to show the new one, not whoever was there before.
class _Server implements ReadAccountRepository {
  /// Who the server currently believes is signed in.
  AccountSummary? signedIn;
  int calls = 0;

  @override
  Future<AccountSummary?> getAccount(String userId) async {
    calls++;
    return signedIn;
  }

  @override
  Stream<AccountSummary> watchAccount(String userId) => const Stream.empty();

  @override
  Future<void> refresh(String userId) async {}
}

AccountSummary _account(String id, String name) => AccountSummary(
      id: UserId.value(id),
      displayName: name,
      countryCode: 'EG',
      preferredLanguage: 'en',
      deletionState: 'ACTIVE',
    );

void main() {
  final session = StateProvider<UserId?>((ref) => null);

  ({ProviderContainer container, _Server server}) boot() {
    final server = _Server();
    final container = ProviderContainer(overrides: [
      readAccountRepositoryProvider.overrideWithValue(server),
      currentUserIdProvider.overrideWith((ref) => ref.watch(session)),
    ]);
    addTearDown(container.dispose);
    return (container: container, server: server);
  }

  test('after sign-out and a new sign-up, the summary is the new account', () async {
    final (:container, :server) = boot();

    server.signedIn = _account('u-1', 'First Patient');
    container.read(session.notifier).state = const UserId.value('u-1');
    // Something on screen keeps the provider alive across the whole flow,
    // exactly as the signed-in shell does.
    final sub = container.listen(accountSummaryProvider, (_, __) {});
    addTearDown(sub.close);
    expect((await container.read(accountSummaryProvider.future))?.displayName, 'First Patient');

    // Sign out.
    server.signedIn = null;
    container.read(session.notifier).state = null;
    expect(await container.read(accountSummaryProvider.future), isNull);

    // A different person registers on the same device.
    server.signedIn = _account('u-2', 'Second Patient');
    container.read(session.notifier).state = const UserId.value('u-2');
    expect((await container.read(accountSummaryProvider.future))?.displayName, 'Second Patient');
  });

  test('signed out, nobody is shown and the server is not asked', () async {
    final (:container, :server) = boot();
    server.signedIn = _account('u-1', 'First Patient');

    expect(await container.read(accountSummaryProvider.future), isNull);
    expect(server.calls, 0, reason: 'there is no session to ask about');
  });
}
