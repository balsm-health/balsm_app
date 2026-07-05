// emergency_card — public API barrel.
// Import via: import 'package:emergency_card/emergency_card.dart';

// Domain — aggregates
export 'src/domain/aggregates/emergency_card_snapshot.dart';
export 'src/domain/aggregates/emergency_qr_token.dart';

// Domain — events
export 'src/domain/events/emergency_qr_token_minted.dart';
export 'src/domain/events/emergency_qr_token_revoked.dart';

// Application — snapshot reader port + use cases
export 'src/application/emergency_snapshot_reader.dart';
export 'src/application/use_cases/mint_emergency_qr_token_use_case.dart';
export 'src/application/use_cases/revoke_emergency_qr_token_use_case.dart';
export 'src/application/use_cases/resolve_emergency_qr_token_use_case.dart';

// Presentation — screens
export 'src/presentation/screens/emergency_card_screen.dart';
export 'src/presentation/screens/qr_code_display_screen.dart';
export 'src/presentation/screens/public_emergency_resolve_screen.dart';

// Presentation — routes
export 'src/presentation/routes.dart';

// Presentation — lock-screen widget data class
export 'src/presentation/widgets/emergency_lock_screen_widget.dart';
