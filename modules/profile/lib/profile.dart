// profile package — public API barrel.
//
// PHI bounded context: all health-profile data is stored ON-DEVICE ONLY
// (SQLCipher) and never transmitted to the cloud. Infrastructure/drift
// internals are intentionally NOT exported.

// Domain
export 'src/domain/aggregates/health_profile.dart';
export 'src/domain/events/health_profile_updated.dart';
export 'src/domain/value_objects/ids.dart';

// Application — use cases
export 'src/application/use_cases/update_health_profile_use_case.dart';
export 'src/application/use_cases/add_allergy_use_case.dart';
export 'src/application/use_cases/remove_allergy_use_case.dart';
export 'src/application/use_cases/add_chronic_condition_use_case.dart';
export 'src/application/use_cases/add_emergency_contact_use_case.dart';

// Infrastructure — read access for app-shell seams (e.g. emergency snapshot).
// PHI stays on-device regardless of who reads the DAO.
export 'src/infrastructure/drift/profile_dao.dart';

// Presentation
export 'src/presentation/screens/health_profile_editor_screen.dart';
export 'src/presentation/routes.dart';
