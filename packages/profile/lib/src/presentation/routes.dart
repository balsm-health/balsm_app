import 'package:go_router/go_router.dart';

import 'screens/health_profile_editor_screen.dart';

/// Route table for the profile bounded context. Wired into the app shell router.
final profileRoutes = <RouteBase>[
  GoRoute(
    path: '/profile/editor',
    name: 'profile.editor',
    builder: (_, __) => const HealthProfileEditorScreen(),
  ),
];
