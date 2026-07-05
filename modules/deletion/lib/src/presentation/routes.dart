import 'package:go_router/go_router.dart';

import 'screens/delete_account_screen.dart';
import 'screens/deletion_cancelled_screen.dart';
import 'screens/deletion_confirm_screen.dart';
import 'screens/public_delete_cancelled_screen.dart';
import 'screens/public_delete_screen.dart';

/// Routes for the deletion bounded context.
///
/// `deletion.public` and `deletion.publicCancelled` are PUBLIC (no session
/// required) — the router auth guard must allowlist them.
final deletionRoutes = <RouteBase>[
  GoRoute(
    path: '/deletion/request',
    name: 'deletion.request',
    builder: (_, __) => const DeleteAccountScreen(),
  ),
  GoRoute(
    path: '/deletion/confirm',
    name: 'deletion.confirm',
    builder: (_, __) => const DeletionConfirmScreen(),
  ),
  GoRoute(
    path: '/deletion/cancelled',
    name: 'deletion.cancelled',
    builder: (_, __) => const DeletionCancelledScreen(),
  ),
  // NO auth — public deletion entry. Router allowlist: '/account/delete'.
  GoRoute(
    path: '/account/delete',
    name: 'deletion.public',
    builder: (_, __) => const PublicDeleteScreen(),
  ),
  // NO auth — public cancellation entry. Router allowlist:
  // '/account/delete-cancelled'.
  GoRoute(
    path: '/account/delete-cancelled',
    name: 'deletion.publicCancelled',
    builder: (_, __) => const PublicDeleteCancelledScreen(),
  ),
];
