// account package — public API barrel

// Domain
// AccountSummary + ReadAccountRepository moved to core (cross-module read
// contract); consumers import them from `package:core/core.dart`.

// Application
export 'src/application/ports/denied_countries_port.dart';
export 'src/application/use_cases/claim_handle_use_case.dart';
export 'src/application/use_cases/account_profile_use_case.dart';
export 'src/application/use_cases/change_country_use_case.dart';
export 'src/application/use_cases/change_language_use_case.dart';

// Infrastructure — the concrete adapter + its builder, for the app to bind
// into core's `readAccountRepositoryProvider` port.
export 'src/infrastructure/api/balsm_account_adapter.dart' show BalsmAccountAdapter, buildAccountAdapter;

// Presentation
export 'src/presentation/screens/settings_screen.dart';
export 'src/presentation/screens/country_settings_screen.dart';
export 'src/presentation/screens/language_settings_screen.dart';
export 'src/presentation/screens/handle_claim_screen.dart';
export 'src/presentation/routes.dart';
