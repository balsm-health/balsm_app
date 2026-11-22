/// Self-report / check-in bounded context — the patient's on-device symptom,
/// pain, mood, and vitals journal. PHI, on-device only (no server endpoint).
///
/// A journal, NOT a symptom checker: the symptom/body-region catalogs are
/// closed reference data and carry no clinical interpretation or advice.
library;

export 'src/application/full_check_in_plan.dart';
// Application
export 'src/application/ports/check_ins_data_source.dart';
export 'src/application/use_cases/edit_check_in_reading_use_case.dart';
export 'src/application/use_cases/list_check_ins_use_case.dart';
export 'src/application/use_cases/save_check_in_use_case.dart';
export 'src/application/use_cases/update_check_in_use_case.dart';
// Domain
export 'src/domain/aggregates/check_in.dart';
export 'src/domain/events/check_in_saved.dart';
export 'src/domain/value_objects/body_region.dart';
export 'src/domain/value_objects/body_tissue.dart';
export 'src/domain/value_objects/check_in_metric.dart';
export 'src/domain/value_objects/ids.dart';
export 'src/domain/value_objects/latest_readings.dart';
export 'src/domain/value_objects/mood.dart';
export 'src/domain/value_objects/pain_level.dart';
export 'src/domain/value_objects/pain_site.dart';
export 'src/domain/value_objects/symptom.dart';
export 'src/domain/value_objects/symptom_detail.dart';
export 'src/domain/value_objects/vital_limits.dart';
export 'src/domain/value_objects/vitals.dart';
export 'src/i18n/strings.dart';
// Infrastructure (provider binding)
export 'src/infrastructure/drift/drift_check_ins_data_source.dart'
    show DriftCheckInsDataSource, checkInsDataSourceProvider;
