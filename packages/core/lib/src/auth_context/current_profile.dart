import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../domain/value_objects/health_profile_id.dart';
import 'current_user.dart';

/// The active health profile — the PHI partition every profile-scoped data
/// source resolves when called with a null scope. Sibling of
/// [currentUserIdProvider] / `currentEntityIdProvider`.
///
/// Today this is always the signed-in user's **self** profile; the dependants
/// feature (P00X) re-points it from the profile switcher. Null while signed
/// out or until [activeProfileProvider] finishes ensuring the row — scoped
/// reads return empty until then and refresh when it resolves.
final currentProfileIdProvider = Provider<HealthProfileId?>(
  (ref) => ref.watch(activeProfileProvider).valueOrNull,
);

/// Resolves (and on first sign-in creates) the self health-profile row for
/// the authenticated user — the session-start guarantee that makes
/// profile-scoped queries correct: no PHI row can stay unanchored once this
/// has run.
final activeProfileProvider = FutureProvider<HealthProfileId?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  final db = ref.watch(appDatabaseProvider);
  return db.ensureSelfHealthProfile(userId);
});
