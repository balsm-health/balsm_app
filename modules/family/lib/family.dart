// family package — public API barrel.
//
// Personal Health (consumer plane): member profiles the account holder
// manages on this device, and the groups they are filed under. PHI stays
// on-device; nothing here talks to the network.

// Domain
export 'src/domain/aggregates/member_group.dart';
export 'src/domain/entities/family_member.dart';
export 'src/domain/services/family_grouping.dart';
export 'src/domain/value_objects/default_group.dart';
export 'src/domain/value_objects/member_age.dart';
export 'src/domain/value_objects/member_draft.dart';
export 'src/domain/value_objects/member_tone.dart';

// Application
export 'src/application/ports/family_members_port.dart';
export 'src/application/ports/member_groups_data_source.dart';
export 'src/application/use_cases/close_family_member_use_case.dart';
export 'src/application/use_cases/ensure_default_groups_use_case.dart';
export 'src/application/use_cases/save_family_member_use_case.dart';

// Infrastructure — bound through its provider; the class is exported for tests.
export 'src/infrastructure/drift/drift_member_groups_data_source.dart';

// Presentation — providers
export 'src/presentation/providers.dart';
