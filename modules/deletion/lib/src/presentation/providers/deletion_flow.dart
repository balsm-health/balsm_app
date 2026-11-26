import 'package:core/core.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;

import '../../application/ports/reauth_port.dart';
import '../../application/use_cases/cancel_deletion_use_case.dart';
import '../../application/use_cases/request_deletion_use_case.dart';

/// Where the person entered the deletion flow. Each entry opens on its own
/// stage and decides what a verified code unlocks.
enum DeletionEntry {
  /// `/account/delete`: verify, then confirm the request.
  publicDelete,

  /// `/account/delete` opened from the emailed link, already redeemed for a
  /// session: the confirmation step, no form.
  publicDeleteVerified,

  /// `/account/delete-cancelled`: verify, then cancel at once.
  publicCancel,

  /// The signed-in "Are you sure?" screen.
  confirm,

  /// Signed in to an account that is already scheduled for deletion.
  postLogin,
}

/// The step the flow is on.
enum DeletionStage {
  /// Waiting for the one-time code.
  reauth,

  /// Identity proven (or a session exists); the request has not been sent.
  preconfirm,

  /// The server has scheduled the deletion.
  scheduled,

  /// The pending deletion was cancelled.
  cancelled,
}

/// What a deletion screen shows: the step, the chosen re-auth channel, whether
/// a request is in flight, the last failure, and the server's grace deadline.
///
/// Holds no credentials: the identifier and the code pass through
/// [DeletionFlowNotifier.verify] and are never kept.
@immutable
class DeletionFlow {
  const DeletionFlow({
    required this.stage,
    this.channel = ReauthChannel.email,
    this.submitting = false,
    this.failure,
    this.graceUntil,
  });

  final DeletionStage stage;
  final ReauthChannel channel;
  final bool submitting;

  /// The last failure from the port or a use case; its message is shown.
  final AppFailure? failure;

  /// When the server will purge the account, once it has been scheduled.
  final DateTime? graceUntil;

  DeletionFlow copyWith({
    DeletionStage? stage,
    ReauthChannel? channel,
    bool? submitting,
    DateTime? graceUntil,
  }) =>
      DeletionFlow(
        stage: stage ?? this.stage,
        channel: channel ?? this.channel,
        submitting: submitting ?? this.submitting,
        failure: failure,
        graceUntil: graceUntil ?? this.graceUntil,
      );

  /// A request starts: in flight, previous failure cleared.
  DeletionFlow started() => DeletionFlow(stage: stage, channel: channel, submitting: true, graceUntil: graceUntil);

  /// A request failed: back to idle on the same step, showing [f].
  DeletionFlow failed(AppFailure f) => DeletionFlow(stage: stage, channel: channel, failure: f, graceUntil: graceUntil);

  DeletionFlow withoutFailure() => DeletionFlow(
        stage: stage,
        channel: channel,
        submitting: submitting,
        graceUntil: graceUntil,
      );

  @override
  bool operator ==(Object other) =>
      other is DeletionFlow &&
      other.stage == stage &&
      other.channel == channel &&
      other.submitting == submitting &&
      other.failure == failure &&
      other.graceUntil == graceUntil;

  @override
  int get hashCode => Object.hash(stage, channel, submitting, failure, graceUntil);
}

/// The request / verify / cancel flow shared by the deletion screens.
///
/// Every method checks `ref.mounted` after its await: the screen can be left
/// mid-request, and an auto-disposed notifier must not be written to.
class DeletionFlowNotifier extends Notifier<DeletionFlow> {
  DeletionFlowNotifier(this.entry);

  final DeletionEntry entry;

  @override
  DeletionFlow build() => DeletionFlow(
        stage: switch (entry) {
          DeletionEntry.publicDelete || DeletionEntry.publicCancel => DeletionStage.reauth,
          DeletionEntry.publicDeleteVerified || DeletionEntry.confirm => DeletionStage.preconfirm,
          DeletionEntry.postLogin => DeletionStage.scheduled,
        },
      );

  void selectChannel(ReauthChannel channel) => state = state.copyWith(channel: channel);

  /// Sends the one-time code. The form stays usable meanwhile, so this does not
  /// mark the flow as submitting.
  Future<void> sendCode(String identifier) async {
    state = state.withoutFailure();
    final sent = await ref.read(reauthPortProvider).requestChallenge(state.channel, identifier);
    if (!ref.mounted) return;
    if (sent case AppFailureResult(:final failure)) state = state.failed(failure);
  }

  /// Verifies the code. Nothing here trusts the form: the only way past this
  /// step is a success from [ReauthPort], whose default implementation refuses.
  /// The public delete entry then asks for confirmation; the public cancel
  /// entry cancels at once, since cancelling another person's deletion takes
  /// the same proof.
  Future<void> verify(ReauthCredentials credentials) async {
    if (state.submitting) return;
    state = state.started();
    final proof = await ref.read(reauthPortProvider).verify(credentials);
    if (!ref.mounted) return;
    if (proof case AppFailureResult(:final failure)) {
      state = state.failed(failure);
      return;
    }
    if (entry == DeletionEntry.publicCancel) {
      await _cancel();
    } else {
      state = state.copyWith(stage: DeletionStage.preconfirm, submitting: false);
    }
  }

  /// `POST /deletion/intake`; on success the flow holds the grace deadline.
  Future<void> requestDeletion() async {
    if (state.submitting) return;
    state = state.started();
    final result = await ref.read(requestDeletionUseCaseProvider).call();
    if (!ref.mounted) return;
    state = result.fold(
      (intake) => state.copyWith(stage: DeletionStage.scheduled, submitting: false, graceUntil: intake.graceUntil),
      state.failed,
    );
  }

  /// `POST /deletion/cancel` for a scheduled deletion.
  Future<void> cancelDeletion() async {
    if (state.submitting) return;
    state = state.started();
    await _cancel();
  }

  Future<void> _cancel() async {
    final result = await ref.read(cancelDeletionUseCaseProvider).call();
    if (!ref.mounted) return;
    state = result.fold(
      (_) => state.copyWith(stage: DeletionStage.cancelled, submitting: false),
      state.failed,
    );
  }
}

/// One flow per entry point, dropped when its screen closes.
final NotifierProviderFamily<DeletionFlowNotifier, DeletionFlow, DeletionEntry> deletionFlowProvider =
    NotifierProvider.autoDispose.family<DeletionFlowNotifier, DeletionFlow, DeletionEntry>(DeletionFlowNotifier.new);
