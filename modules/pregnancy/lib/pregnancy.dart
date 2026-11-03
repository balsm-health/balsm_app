// pregnancy package — public API barrel.
//
// Personal Health (consumer plane): a pregnancy tracked on the account
// holder's own profile, the babies it carries (prenatal profiles), what is
// recorded along the way, and birth. PHI stays on-device; nothing here talks
// to the network.

// Domain
export 'src/domain/aggregates/pregnancy.dart';
export 'src/domain/entities/pregnancy_baby.dart';
export 'src/domain/entities/pregnancy_item.dart';
export 'src/domain/value_objects/birth_details.dart';
export 'src/domain/value_objects/ids.dart';
export 'src/domain/value_objects/pregnancy_dates.dart';
export 'src/domain/value_objects/pregnancy_enums.dart';

// Application
export 'src/application/ports/pregnancies_data_source.dart';
export 'src/application/ports/pregnancy_babies_port.dart';
export 'src/application/use_cases/end_pregnancy_use_case.dart';
export 'src/application/use_cases/pregnancy_babies_use_case.dart';
export 'src/application/use_cases/pregnancy_records_use_case.dart';
export 'src/application/use_cases/record_birth_use_case.dart';
export 'src/application/use_cases/start_pregnancy_use_case.dart';

// Infrastructure — bound through its provider; the class is exported for tests.
export 'src/infrastructure/drift/drift_pregnancies_data_source.dart';

// Presentation — providers
export 'src/presentation/providers.dart';
