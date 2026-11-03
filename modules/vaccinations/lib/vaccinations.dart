// vaccinations package — public API barrel.
//
// Personal Health (consumer plane): the vaccination log kept per person on
// this device. PHI stays on-device; nothing here talks to the network.

// Domain
export 'src/domain/aggregates/vaccination_record.dart';
export 'src/domain/services/vaccination_status.dart';
export 'src/domain/value_objects/ids.dart';

// Application
export 'src/application/ports/vaccinations_data_source.dart';
export 'src/application/use_cases/record_vaccination_use_case.dart';

// Infrastructure — bound through its provider; the class is exported for tests.
export 'src/infrastructure/drift/drift_vaccinations_data_source.dart';

// Presentation — providers
export 'src/presentation/providers.dart';
