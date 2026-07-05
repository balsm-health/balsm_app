// account package — public API barrel

// Domain
export 'src/domain/value_objects/account_summary.dart';
export 'src/domain/events/country_changed.dart';
export 'src/domain/events/language_changed.dart';
export 'src/domain/repositories/read_account_repository.dart';

// Application
export 'src/application/ports/denied_countries_port.dart';
export 'src/application/use_cases/claim_handle_use_case.dart';
export 'src/application/use_cases/change_country_use_case.dart';
export 'src/application/use_cases/change_language_use_case.dart';

// Infrastructure (providers)
export 'src/infrastructure/api/balsm_account_adapter.dart'
    show
        BalsmAccountAdapter,
        readAccountRepositoryProvider,
        accountSummaryProvider;

// Presentation
export 'src/presentation/screens/settings_screen.dart';
export 'src/presentation/screens/country_settings_screen.dart';
export 'src/presentation/screens/language_settings_screen.dart';
export 'src/presentation/screens/handle_claim_screen.dart';
export 'src/presentation/routes.dart';
