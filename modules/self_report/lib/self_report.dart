/// Self-report / check-in bounded context — the patient's on-device symptom,
/// pain, mood, and vitals journal. PHI, on-device only (no server endpoint).
///
/// A journal, NOT a symptom checker: the symptom/body-region catalogs are
/// closed reference data and carry no clinical interpretation or advice.
library;

// Domain
export 'src/domain/aggregates/check_in.dart';
export 'src/domain/events/check_in_saved.dart';
export 'src/domain/value_objects/ids.dart';
export 'src/domain/value_objects/mood.dart';
export 'src/domain/value_objects/pain_level.dart';
export 'src/domain/value_objects/symptom.dart';
export 'src/domain/value_objects/body_region.dart';
export 'src/domain/value_objects/vitals.dart';
export 'src/domain/value_objects/check_in_metric.dart';
export 'src/i18n/strings.dart';

// Application
export 'src/application/ports/check_ins_data_source.dart';
export 'src/application/use_cases/save_check_in_use_case.dart';
export 'src/application/use_cases/list_check_ins_use_case.dart';
export 'src/application/full_check_in_plan.dart';

// Infrastructure (provider binding)
export 'src/infrastructure/drift/drift_check_ins_data_source.dart'
    show checkInsDataSourceProvider, DriftCheckInsDataSource;
