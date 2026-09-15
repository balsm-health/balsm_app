import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/aggregates/profile_qr_payload.dart';

/// Reads the current patient's identity fields into a [ProfileQrPayload]
/// (spec v2.0: name, date of birth, gender, language). The implementation
/// lives in app wiring and adapts the account profile; this keeps the
/// emergency_card bounded context decoupled from account internals.
///
/// MUST always return a payload — when the profile is unavailable (offline,
/// signed out mid-flow) return one with null identity fields; the standing
/// refresh path fills them in later. The payload contains identity PHI and
/// MUST NOT be logged or sent to Sentry.
abstract class ProfileIdentityReader {
  Future<ProfileQrPayload> readIdentity();
}

/// Override this in the app `ProviderScope` with a concrete implementation
/// that adapts the account profile into a [ProfileIdentityReader].
final profileIdentityReaderProvider = Provider<ProfileIdentityReader>((ref) {
  throw UnimplementedError(
    'Override profileIdentityReaderProvider in the app ProviderScope '
    'with an account-backed ProfileIdentityReader.',
  );
});
