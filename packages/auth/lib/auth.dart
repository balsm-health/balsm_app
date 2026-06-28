// auth package — public API barrel.
//
// Exposes the domain, application, and presentation surface of the auth bounded
// context. Infrastructure internals (adapters, exceptions, secure-storage repo
// implementations) are intentionally NOT exported — depend on the abstractions
// and providers below.

// ── Domain ──────────────────────────────────────────────────────────────────
export 'src/domain/aggregates/auth_session.dart';
export 'src/domain/events/lockout_triggered.dart';
export 'src/domain/events/user_signed_in.dart';
export 'src/domain/events/user_signed_out.dart';
export 'src/domain/events/user_signed_up.dart';
export 'src/domain/repositories/read_auth_repository.dart';

// ── Application ─────────────────────────────────────────────────────────────
export 'src/application/use_cases/sign_in_use_case.dart';
export 'src/application/use_cases/sign_out_use_case.dart';
export 'src/application/use_cases/sign_up_use_case.dart';

// ── Presentation ────────────────────────────────────────────────────────────
export 'src/presentation/providers/auth_providers.dart';
export 'src/presentation/routes.dart';
