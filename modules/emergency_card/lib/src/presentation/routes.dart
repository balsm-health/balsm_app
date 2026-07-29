import 'package:go_router/go_router.dart';

import '../domain/aggregates/emergency_qr_token.dart';
import 'screens/emergency_card_screen.dart';
import 'screens/public_emergency_resolve_screen.dart';
import 'screens/qr_code_display_screen.dart';

/// Payload for the `emergency.qrDisplay` route, passed via `extra`.
typedef EmergencyQrDisplayArgs = ({EmergencyQrToken token, String qrUrl});

// NOTE FOR APP ROUTER WIRING:
// The `emergency.publicResolve` route (`/emergency/public/:token`) is PUBLIC and
// MUST be reachable WITHOUT authentication. The app router's redirect/auth guard
// MUST allowlist any path starting with `/emergency/public/` so unauthenticated
// first responders can resolve a scanned QR.
final emergencyCardRoutes = <RouteBase>[
  GoRoute(
    path: '/emergency/card',
    name: 'emergency.card',
    builder: (_, __) => const EmergencyCardScreen(),
  ),
  GoRoute(
    path: '/emergency/qr',
    name: 'emergency.qrDisplay',
    builder: (_, state) {
      final args = state.extra as EmergencyQrDisplayArgs?;
      if (args == null) {
        // Nothing to display without a minted token — send back to the card.
        return const EmergencyCardScreen();
      }
      return QrCodeDisplayScreen(token: args.token, qrUrl: args.qrUrl);
    },
  ),
  GoRoute(
    path: '/emergency/public/:token',
    name: 'emergency.publicResolve',
    builder: (_, s) => PublicEmergencyResolveScreen(
      tokenId: s.pathParameters['token']!,
      // Mobile deeplink forwards the key as a query param / route extra; web
      // reads the URL fragment internally.
      keyOverride: s.uri.queryParameters['k'] ?? (s.extra is Map ? (s.extra as Map)['key'] as String? : null),
    ),
  ),
];
