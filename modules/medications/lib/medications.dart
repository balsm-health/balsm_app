// medications package — public API barrel.

// Domain — aggregate & entity
export 'src/domain/aggregates/medication.dart';
export 'src/domain/entities/dose_event.dart';

// Domain — events
export 'src/domain/events/medication_added.dart';
export 'src/domain/events/dose_taken.dart';
export 'src/domain/events/dose_skipped.dart';
export 'src/domain/events/dose_snoozed.dart';
export 'src/domain/events/dose_missed.dart';
export 'src/domain/events/dose_corrected.dart';
export 'src/domain/value_objects/ids.dart';

// Infrastructure
export 'src/infrastructure/drift/medications_data_source.dart';
export 'src/infrastructure/drift/medication_scheduler.dart';
export 'src/infrastructure/drift/missed_dose_detector.dart';

// Application — use cases
export 'src/application/use_cases/add_medication_use_case.dart';
export 'src/application/use_cases/record_dose_outcome_use_case.dart';
export 'src/application/use_cases/edit_medication_use_case.dart';
export 'src/application/use_cases/delete_medication_use_case.dart';
export 'src/application/use_cases/notify_missed_doses_use_case.dart';

// Presentation — providers, screens & routes
export 'src/presentation/providers.dart';
export 'src/presentation/routes.dart';
export 'src/presentation/screens/medication_list_screen.dart';
export 'src/presentation/screens/add_medication_screen.dart';
export 'src/presentation/screens/dose_history_screen.dart';
export 'src/presentation/screens/today_screen.dart';

// Presentation — existing widgets
export 'src/presentation/widgets/permission_request_sheet.dart';
export 'src/presentation/widgets/dedup_banner.dart';
