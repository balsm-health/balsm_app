import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/value_objects/user_id.dart';

/// The authenticated user's id (opaque cloud account id, non-PHI).
///
/// Overridden in the app shell's `bootstrap()` with the value read from
/// `SecureStorageWrapper` (key `balsm.user_id`) after sign-in, and invalidated
/// on sign-out. Returns null when no user is authenticated.
///
/// Modules read this instead of any auth/identity client so they stay
/// decoupled from the auth package.
final currentUserIdProvider = Provider<UserId?>(
  (ref) => null,
);
