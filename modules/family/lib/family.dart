// family package — public API barrel.
//
// Personal Health (consumer plane): member profiles the account holder
// manages on this device, the groups they are filed under, and each
// person's growth log. PHI stays on-device; nothing here talks to the
// network.

// Domain
export 'src/domain/aggregates/growth_entry.dart';
export 'src/domain/aggregates/member_group.dart';
export 'src/domain/entities/family_member.dart';
export 'src/domain/services/family_grouping.dart';
export 'src/domain/value_objects/default_group.dart';
export 'src/domain/value_objects/growth_entry_id.dart';
export 'src/domain/value_objects/member_age.dart';
export 'src/domain/value_objects/member_draft.dart';
export 'src/domain/value_objects/member_tone.dart';

// Application
export 'src/application/ports/family_members_port.dart';
export 'src/application/ports/growth_log_data_source.dart';
export 'src/application/ports/member_groups_data_source.dart';
export 'src/application/use_cases/close_family_member_use_case.dart';
export 'src/application/use_cases/ensure_default_groups_use_case.dart';
export 'src/application/use_cases/record_growth_entry_use_case.dart';
export 'src/application/use_cases/save_family_member_use_case.dart';

// Infrastructure — bound through its providers; the classes are exported for tests.
export 'src/infrastructure/drift/drift_growth_log_data_source.dart';
export 'src/infrastructure/drift/drift_member_groups_data_source.dart';

// Presentation — providers
export 'src/presentation/growth_providers.dart';
export 'src/presentation/providers.dart';
