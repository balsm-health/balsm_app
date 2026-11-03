import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../domain/value_objects/health_profile_id.dart';
import 'current_user.dart';

/// The active health profile — the PHI partition every profile-scoped data
/// source resolves when called with a null scope. Sibling of
/// [currentUserIdProvider] / `currentEntityIdProvider`.
///
/// Follows [activeProfileProvider]: the profile the signed-in account selected
/// on this device (via [activeProfileSwitcherProvider]), or its **self**
/// profile when nothing — or nothing still valid — is selected. Null while
/// signed out or until [activeProfileProvider] first resolves; scoped reads
/// return empty until then and refresh when it resolves. While a switch
/// re-resolves, the previous value is kept, so scoped screens never flash
/// empty.
final currentProfileIdProvider = Provider<HealthProfileId?>(
  (ref) => ref.watch(activeProfileProvider).valueOrNull,
);

/// Resolves the active profile for the authenticated user, ensuring (and on
/// first sign-in creating) the self row first — the session-start guarantee
/// that makes profile-scoped queries correct: no PHI row can stay unanchored
/// once this has run.
///
/// A selection that is missing, closed, or owned by another account falls
/// back to self (`AppDatabase.resolveActiveHealthProfile`).
final activeProfileProvider = FutureProvider<HealthProfileId?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  final db = ref.watch(appDatabaseProvider);
  return db.resolveActiveHealthProfile(userId);
});

/// The signed-in account's own (self) profile, whichever profile is active.
/// Created on first read like [activeProfileProvider]. For "my own" data that
/// must not follow the switcher.
final selfProfileIdProvider = FutureProvider<HealthProfileId?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  final db = ref.watch(appDatabaseProvider);
  return db.ensureSelfHealthProfile(userId);
});

/// Re-points [currentProfileIdProvider] — the one way to switch whose data
/// the profile-scoped modules read and write. The selection is persisted per
/// account on this device (in the encrypted database) and survives restarts.
class ActiveProfileSwitcher {
  ActiveProfileSwitcher(this._ref);

  final Ref _ref;

  /// Makes [profileId] the active profile. Returns false — and leaves the
  /// active profile unchanged — when signed out, or when [profileId] is not
  /// an active (non-closed) profile of the signed-in account.
  Future<bool> select(HealthProfileId profileId) async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return false;
    final ok = await _ref.read(appDatabaseProvider).setActiveHealthProfile(userId, profileId);
    if (ok) _ref.invalidate(activeProfileProvider);
    return ok;
  }

  /// Back to the account holder's self profile.
  Future<void> selectSelf() async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return;
    await _ref.read(appDatabaseProvider).setActiveHealthProfile(userId, null);
    _ref.invalidate(activeProfileProvider);
  }

  /// Re-resolves the active profile without changing the selection — call
  /// after closing or removing a profile so a now-invalid selection falls
  /// back to self.
  void refresh() => _ref.invalidate(activeProfileProvider);
}

final activeProfileSwitcherProvider = Provider<ActiveProfileSwitcher>(ActiveProfileSwitcher.new);
