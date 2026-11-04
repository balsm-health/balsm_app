// family_link package — public API barrel.
//
// Identity & Access (cross-plane): links between two Balsm accounts made by
// scanning a profile QR and approved in the other person's app, and the
// emergency card each side may share, sealed so only the other person's
// phone can open it. The server never holds health data in readable form.

// Domain
export 'src/domain/entities/family_link.dart';
export 'src/domain/value_objects/emergency_card_payload.dart';
export 'src/domain/value_objects/link_direction.dart';
export 'src/domain/value_objects/link_relation.dart';
export 'src/domain/value_objects/sealed_card.dart';

// Application
export 'src/application/link_failures.dart';
export 'src/application/ports/card_sealer.dart';
export 'src/application/ports/device_key_store.dart';
export 'src/application/ports/link_local_store.dart';
export 'src/application/ports/own_emergency_card_reader.dart';
export 'src/application/use_cases/end_family_link_use_case.dart';
export 'src/application/use_cases/read_shared_card_use_case.dart';
export 'src/application/use_cases/refresh_family_links_use_case.dart';
export 'src/application/use_cases/request_family_link_use_case.dart';
export 'src/application/use_cases/respond_to_family_link_use_case.dart';
export 'src/application/use_cases/set_card_sharing_use_case.dart';

// Infrastructure — bound through its providers; the classes are exported for tests.
export 'src/infrastructure/crypto/ecies_card_sealer.dart';
export 'src/infrastructure/secure/secure_device_key_store.dart';
export 'src/infrastructure/secure/secure_link_local_store.dart';

// Presentation — providers
export 'src/presentation/providers.dart';
