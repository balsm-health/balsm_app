// deletion package — public API barrel

// Domain
export 'src/domain/aggregates/deletion_request.dart';
export 'src/domain/events/deletion_events.dart';

// Application
export 'src/application/use_cases/request_deletion_use_case.dart';
export 'src/application/use_cases/cancel_deletion_use_case.dart';

// Presentation — screens
export 'src/presentation/screens/delete_account_screen.dart';
export 'src/presentation/screens/deletion_confirm_screen.dart';
export 'src/presentation/screens/deletion_cancelled_screen.dart';
export 'src/presentation/screens/post_deletion_login_screen.dart';
export 'src/presentation/screens/public_delete_screen.dart';
export 'src/presentation/screens/public_delete_cancelled_screen.dart';

// Presentation — routes
export 'src/presentation/routes.dart';
