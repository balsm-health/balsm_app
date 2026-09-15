// emergency_card — public API barrel.
// Import via: import 'package:emergency_card/emergency_card.dart';

// Domain — aggregates
export 'src/domain/aggregates/emergency_card_snapshot.dart';
export 'src/domain/aggregates/emergency_qr_token.dart';
export 'src/domain/aggregates/profile_qr_payload.dart';

// Domain — events
export 'src/domain/events/emergency_qr_token_minted.dart';
export 'src/domain/events/emergency_qr_token_revoked.dart';
export 'src/domain/value_objects/ids.dart';

// Application — snapshot reader port + use cases
export 'src/application/emergency_snapshot_reader.dart';
export 'src/application/profile_identity_reader.dart';
export 'src/application/permanent_qr_store.dart';
export 'src/application/use_cases/mint_emergency_qr_token_use_case.dart';
export 'src/application/use_cases/refresh_permanent_qr_use_case.dart';
export 'src/application/use_cases/revoke_emergency_qr_token_use_case.dart';
export 'src/application/use_cases/resolve_emergency_qr_token_use_case.dart';
export 'src/application/use_cases/rotate_permanent_qr_use_case.dart';
export 'src/application/use_cases/get_qr_scan_history_use_case.dart';

// Presentation — screens
export 'src/presentation/screens/public_emergency_resolve_screen.dart';

// Presentation — routes

// Presentation — lock-screen widget data class
