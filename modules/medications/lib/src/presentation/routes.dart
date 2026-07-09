import 'package:go_router/go_router.dart';

import '../domain/value_objects/ids.dart';
import 'screens/add_medication_screen.dart';
import 'screens/dose_history_screen.dart';
import 'screens/medication_list_screen.dart';
import 'screens/today_screen.dart';

/// Routes contributed by the medications module. Mount these in the app shell's
/// router.
final medicationRoutes = <RouteBase>[
  GoRoute(
    path: '/medications',
    name: 'medications.list',
    builder: (_, __) => const MedicationListScreen(),
    // Child routes use relative subpaths so go_router matches them as a
    // stack on top of the list rather than as flat siblings — flat sibling
    // paths where one ('/medications') is a prefix of another
    // ('/medications/add') resolve to the shorter parent and never advance.
    routes: [
      GoRoute(
        path: 'add',
        name: 'medications.add',
        builder: (_, __) => const AddMedicationScreen(),
      ),
      GoRoute(
        path: 'today',
        name: 'meds.today',
        builder: (_, s) => TodayScreen(
          highlightDoseId: s.uri.queryParameters['highlightDoseId'],
        ),
      ),
      GoRoute(
        path: ':id/history',
        name: 'medications.detail',
        builder: (_, s) => DoseHistoryScreen(
          medicationId: MedicationId.value(s.pathParameters['id']!),
        ),
      ),
    ],
  ),
];
