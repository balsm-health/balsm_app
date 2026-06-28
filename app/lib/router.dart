import 'package:account/account.dart';
import 'package:auth/auth.dart';
import 'package:core/core.dart';
import 'package:deletion/deletion.dart';
import 'package:disclosure/disclosure.dart';
import 'package:emergency_card/emergency_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geofence_block/geofence_block.dart';
import 'package:go_router/go_router.dart';
import 'package:home/home.dart';
import 'package:medications/medications.dart';
import 'package:profile/profile.dart';
import 'package:sessions/sessions.dart';

/// Public (no-auth) path prefixes. The redirect guard never bounces these to
/// the auth flow — emergency QR resolution and account deletion must work for
/// signed-out users (and from deep links / the web).
const _publicPrefixes = <String>[
  '/auth',
  '/emergency/public/',
  '/account/delete',
  '/account/delete-cancelled',
];

bool _isPublic(String location) =>
    _publicPrefixes.any((p) => location.startsWith(p));

final routerProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(authSessionProvider);

  return GoRouter(
    initialLocation: '/home',
    routes: [
      ...authRoutes,
      ...disclosureRoutes,
      ...geofenceRoutes,
      ...homeRoutes,
      ...accountRoutes,
      ...profileRoutes,
      ...emergencyCardRoutes,
      ...medicationRoutes,
      ...deletionRoutes,
      ...sessionsRoutes,
    ],
    redirect: (context, state) {
      final authenticated = session.valueOrNull is Authenticated;
      final location = state.matchedLocation;
      if (!authenticated && !_isPublic(location)) {
        return '/auth/country';
      }
      return null;
    },
    errorBuilder: (context, state) => const NotFoundScreen(),
  );
});
