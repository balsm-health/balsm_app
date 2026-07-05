import 'package:go_router/go_router.dart';

import 'screens/sessions_screen.dart';

/// Routes for the sessions bounded context.
final sessionsRoutes = <RouteBase>[
  GoRoute(
    path: '/sessions',
    name: 'sessions.list',
    builder: (_, __) => const SessionsScreen(),
  ),
];
