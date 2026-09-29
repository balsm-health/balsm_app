import 'package:core/core.dart';
import 'package:flutter/widgets.dart' show TextInputType;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Identity channel offered during public re-authentication.
enum ReauthChannel { email, phone, handle }

extension ReauthChannelLabel on ReauthChannel {
  String get label => switch (this) {
        ReauthChannel.email => 'Email',
        ReauthChannel.phone => 'Phone',
        ReauthChannel.handle => 'Handle',
      };

  TextInputType get keyboardType => switch (this) {
        ReauthChannel.email => TextInputType.emailAddress,
        ReauthChannel.phone => TextInputType.phone,
        ReauthChannel.handle => TextInputType.text,
      };
}

/// Result of a completed re-authentication form submission.
class ReauthCredentials {
  const ReauthCredentials({
    required this.channel,
    required this.identifier,
    required this.secret,
  });

  final ReauthChannel channel;
  final String identifier;

  /// The one-time code. Never logged, never retained past the call.
  final String secret;
}

/// Proves the person driving the public deletion flow holds the account.
///
/// `deletion` cannot depend on `auth` — modules never depend on each other —
/// so it states what it needs here and the app shell binds the real
/// implementation over `auth`'s OTP use cases.
///
/// The default below FAILS CLOSED. An app that forgets to bind a real
/// implementation cannot advance past re-auth, which is the safe direction for
/// an irreversible action on a health account: a deletion that does not happen
/// is recoverable, one that happens to the wrong account is not.
abstract interface class ReauthPort {
  /// Send a one-time code to [identifier] on [channel].
  Future<AppResult<void>> requestChallenge(ReauthChannel channel, String identifier);

  /// Verify the code the person entered. Success here is the only thing that
  /// may advance the deletion flow.
  Future<AppResult<void>> verify(ReauthCredentials credentials);
}

class _UnboundReauthPort implements ReauthPort {
  const _UnboundReauthPort();

  @override
  Future<AppResult<void>> requestChallenge(ReauthChannel channel, String identifier) async =>
      AppResult.failure(const UnauthorizedFailure());

  @override
  Future<AppResult<void>> verify(ReauthCredentials credentials) async => AppResult.failure(const UnauthorizedFailure());
}

/// Overridden by the app shell with an `auth`-backed implementation.
final reauthPortProvider = Provider<ReauthPort>((ref) => const _UnboundReauthPort());
