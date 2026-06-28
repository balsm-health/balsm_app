import 'package:go_router/go_router.dart';

import 'screens/home_screen.dart';

final homeRoutes = <RouteBase>[
  GoRoute(
    path: '/home',
    name: 'home',
    builder: (_, __) => const HomeScreen(),
  ),
];
