import 'dart:async';

import 'package:core/core.dart';
import 'package:deletion/deletion.dart';
import 'package:deletion/src/presentation/providers/deletion_flow.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers from completers so a test decides when each call returns.
class _FakeReauth implements ReauthPort {
  Completer<AppResult<void>> challenge = Completer();
  Completer<AppResult<void>> verifyAnswer = Completer();
  int verifies = 0;

  @override
  Future<AppResult<void>> requestChallenge(ReauthChannel channel, String identifier) => challenge.future;

  @override
  Future<AppResult<void>> verify(ReauthCredentials credentials) {
    verifies++;
    return verifyAnswer.future;
  }
}

class _FakeRequest implements RequestDeletionUseCase {
  _FakeRequest(this.answer);
  final AppResult<DeletionIntakeResult> answer;

  @override
  Future<AppResult<DeletionIntakeResult>> call() async => answer;
}

class _FakeCancel implements CancelDeletionUseCase {
  _FakeCancel(this.answer);
  final AppResult<DeletionState> answer;
  int calls = 0;

  @override
  Future<AppResult<DeletionState>> call() async {
    calls++;
    return answer;
  }
}

const _credentials = ReauthCredentials(channel: ReauthChannel.email, identifier: 'id', secret: '000000');

void main() {
  late _FakeReauth reauth;
  late _FakeCancel cancel;
  final grace = DateTime.utc(2030);

  ProviderContainer make({AppResult<DeletionIntakeResult>? request, AppResult<DeletionState>? cancelled}) {
    reauth = _FakeReauth();
    cancel = _FakeCancel(cancelled ?? AppResult.success(DeletionState.deletionCancelled));
    final container = ProviderContainer(
      retry: noProviderRetry,
      overrides: [
        reauthPortProvider.overrideWithValue(reauth),
        requestDeletionUseCaseProvider.overrideWithValue(
          _FakeRequest(
            request ??
                AppResult.success(DeletionIntakeResult(graceUntil: grace, state: DeletionState.deletionRequested)),
          ),
        ),
        cancelDeletionUseCaseProvider.overrideWithValue(cancel),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Keeps the auto-dispose flow alive, as a screen watching it would.
  ProviderSubscription<DeletionFlow> hold(ProviderContainer c, DeletionEntry entry) =>
      c.listen(deletionFlowProvider(entry), (_, __) {});

  test('each entry opens on its own stage', () {
    final c = make();
    expect(c.read(deletionFlowProvider(DeletionEntry.publicDelete)).stage, DeletionStage.reauth);
    expect(c.read(deletionFlowProvider(DeletionEntry.publicCancel)).stage, DeletionStage.reauth);
    expect(c.read(deletionFlowProvider(DeletionEntry.publicDeleteVerified)).stage, DeletionStage.preconfirm);
    expect(c.read(deletionFlowProvider(DeletionEntry.confirm)).stage, DeletionStage.preconfirm);
    expect(c.read(deletionFlowProvider(DeletionEntry.postLogin)).stage, DeletionStage.scheduled);
  });

  test('a verified code moves the public delete flow to confirmation', () async {
    final c = make();
    hold(c, DeletionEntry.publicDelete);
    final flow = c.read(deletionFlowProvider(DeletionEntry.publicDelete).notifier);

    final pending = flow.verify(_credentials);
    expect(c.read(deletionFlowProvider(DeletionEntry.publicDelete)).submitting, isTrue);
    reauth.verifyAnswer.complete(AppResult.success(null));
    await pending;

    final state = c.read(deletionFlowProvider(DeletionEntry.publicDelete));
    expect(state.stage, DeletionStage.preconfirm);
    expect(state.submitting, isFalse);
    expect(state.failure, isNull);
  });

  test('a refused code stays on re-auth and shows the failure', () async {
    final c = make();
    hold(c, DeletionEntry.publicDelete);
    final pending = c.read(deletionFlowProvider(DeletionEntry.publicDelete).notifier).verify(_credentials);
    reauth.verifyAnswer.complete(AppResult.failure(const UnauthorizedFailure()));
    await pending;

    final state = c.read(deletionFlowProvider(DeletionEntry.publicDelete));
    expect(state.stage, DeletionStage.reauth);
    expect(state.submitting, isFalse);
    expect(state.failure, isA<UnauthorizedFailure>());
  });

  test('the public cancel entry cancels right after a verified code', () async {
    final c = make();
    hold(c, DeletionEntry.publicCancel);
    final pending = c.read(deletionFlowProvider(DeletionEntry.publicCancel).notifier).verify(_credentials);
    reauth.verifyAnswer.complete(AppResult.success(null));
    await pending;

    expect(cancel.calls, 1);
    expect(c.read(deletionFlowProvider(DeletionEntry.publicCancel)).stage, DeletionStage.cancelled);
  });

  test('requesting deletion holds the server grace deadline', () async {
    final c = make();
    hold(c, DeletionEntry.confirm);
    await c.read(deletionFlowProvider(DeletionEntry.confirm).notifier).requestDeletion();

    final state = c.read(deletionFlowProvider(DeletionEntry.confirm));
    expect(state.stage, DeletionStage.scheduled);
    expect(state.graceUntil, grace);
  });

  test('a failed request keeps the step and clears on the next attempt', () async {
    final c = make(request: AppResult.failure(const NetworkFailure()));
    hold(c, DeletionEntry.confirm);
    final flow = c.read(deletionFlowProvider(DeletionEntry.confirm).notifier);
    await flow.requestDeletion();
    expect(c.read(deletionFlowProvider(DeletionEntry.confirm)).failure, isA<NetworkFailure>());
    expect(c.read(deletionFlowProvider(DeletionEntry.confirm)).stage, DeletionStage.preconfirm);

    final again = flow.requestDeletion();
    expect(c.read(deletionFlowProvider(DeletionEntry.confirm)).failure, isNull);
    await again;
  });

  test('a failed send-code shows the failure without blocking the form', () async {
    final c = make();
    hold(c, DeletionEntry.publicDelete);
    final pending = c.read(deletionFlowProvider(DeletionEntry.publicDelete).notifier).sendCode('id');
    expect(c.read(deletionFlowProvider(DeletionEntry.publicDelete)).submitting, isFalse);
    reauth.challenge.complete(AppResult.failure(const OfflineFailure()));
    await pending;
    expect(c.read(deletionFlowProvider(DeletionEntry.publicDelete)).failure, isA<OfflineFailure>());
  });

  test('a second verify while one is in flight is ignored', () async {
    final c = make();
    hold(c, DeletionEntry.publicDelete);
    final flow = c.read(deletionFlowProvider(DeletionEntry.publicDelete).notifier);
    final first = flow.verify(_credentials);
    await flow.verify(_credentials);
    expect(reauth.verifies, 1);
    reauth.verifyAnswer.complete(AppResult.success(null));
    await first;
  });

  test('the selected channel survives a failure', () async {
    final c = make(request: AppResult.failure(const NetworkFailure()));
    hold(c, DeletionEntry.publicDelete);
    c.read(deletionFlowProvider(DeletionEntry.publicDelete).notifier).selectChannel(ReauthChannel.phone);
    final pending = c.read(deletionFlowProvider(DeletionEntry.publicDelete).notifier).verify(_credentials);
    reauth.verifyAnswer.complete(AppResult.failure(const UnauthorizedFailure()));
    await pending;
    expect(c.read(deletionFlowProvider(DeletionEntry.publicDelete)).channel, ReauthChannel.phone);
  });

  test('leaving the screen mid-verify neither throws nor cancels anything', () async {
    final c = make();
    final sub = hold(c, DeletionEntry.publicCancel);
    final pending = c.read(deletionFlowProvider(DeletionEntry.publicCancel).notifier).verify(_credentials);

    // The screen closes while the code is being checked.
    sub.close();
    await c.pump();

    reauth.verifyAnswer.complete(AppResult.success(null));
    await expectLater(pending, completes);
    expect(cancel.calls, 0, reason: 'a disposed flow must not go on to cancel the deletion');
  });

  test('the state compares by value over every field', () {
    final a = DeletionFlow(stage: DeletionStage.scheduled, graceUntil: DateTime.utc(2030));
    final b = DeletionFlow(stage: DeletionStage.scheduled, graceUntil: DateTime.utc(2030));
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a == a.copyWith(channel: ReauthChannel.handle), isFalse);
    expect(a == a.copyWith(submitting: true), isFalse);
    expect(a == a.failed(const NetworkFailure()), isFalse);
    expect(a == a.copyWith(graceUntil: DateTime.utc(2031)), isFalse);
  });
}
