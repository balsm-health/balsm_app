import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/ports/social_credentials_port.dart';
import '../../application/use_cases/age_gate_use_case.dart';
import '../../application/use_cases/recovery_claim_use_case.dart';
import '../../application/use_cases/sign_in_use_case.dart';
import '../../application/use_cases/sign_out_use_case.dart';
import '../../application/use_cases/sign_up_use_case.dart';
import '../../domain/aggregates/auth_session.dart';
import '../../domain/repositories/read_auth_repository.dart';
import '../../infrastructure/api/balsm_auth_adapter.dart';
import '../../infrastructure/repositories/secure_storage_auth_repository.dart';
import '../../infrastructure/social/apple_credentials_adapter.dart';
import '../../infrastructure/social/google_credentials_adapter.dart';

// ── Repository ────────────────────────────────────────────────────────────────

/// Provides the [ReadAuthRepository] backed by [SecureStorageWrapper].
final readAuthRepositoryProvider = Provider<ReadAuthRepository>((ref) {
  return SecureStorageAuthRepository(
    storage: ref.watch(secureStorageProvider),
    eventBus: ref.watch(eventBusProvider),
  );
});

// ── Session stream ────────────────────────────────────────────────────────────

/// Stream of the current [AuthSession]; updates whenever auth state changes.
/// Widgets should use this to drive navigation guards and UI state.
final authSessionProvider = StreamProvider<AuthSession>((ref) {
  return ref.watch(readAuthRepositoryProvider).watchSession();
});

// ── Use case providers ────────────────────────────────────────────────────────

/// Fail-closed age gate (PDPL / G3). Pure/local — no dependencies.
final ageGateUseCaseProvider = Provider<AgeGateUseCase>((ref) {
  return AgeGateUseCase();
});

final signUpUseCaseProvider = Provider<SignUpUseCase>((ref) {
  return SignUpUseCase(
    adapter: ref.watch(balsmAuthAdapterProvider),
    storage: ref.watch(secureStorageProvider),
    eventBus: ref.watch(eventBusProvider),
  );
});

final signInUseCaseProvider = Provider<SignInUseCase>((ref) {
  return SignInUseCase(
    adapter: ref.watch(balsmAuthAdapterProvider),
    storage: ref.watch(secureStorageProvider),
    eventBus: ref.watch(eventBusProvider),
  );
});

final signOutUseCaseProvider = Provider<SignOutUseCase>((ref) {
  return SignOutUseCase(
    adapter: ref.watch(balsmAuthAdapterProvider),
    storage: ref.watch(secureStorageProvider),
    eventBus: ref.watch(eventBusProvider),
  );
});

/// Claims a support-issued recovery token (FR-046c/d/e). Consumed by
/// [AuthRecoveryClaimScreen].
final recoveryClaimUseCaseProvider = Provider<RecoveryClaimUseCase>((ref) {
  return RecoveryClaimUseCase(
    adapter: ref.watch(balsmAuthAdapterProvider),
    storage: ref.watch(secureStorageProvider),
    eventBus: ref.watch(eventBusProvider),
  );
});

// ── Social credentials ────────────────────────────────────────────────────────

/// Google credentials, configured from the build's OAuth client ids.
///
/// Override in tests to drive the sign-in flow without the SDK.
final googleCredentialsPortProvider = Provider<SocialCredentialsPort>((ref) {
  final config = FlavorConfig.current;
  return GoogleCredentialsAdapter(
    serverClientId: config.googleServerClientId,
    iosClientId: config.googleIosClientId,
  );
});

/// Apple credentials via the native iOS flow. Callers gate the button on iOS.
final appleCredentialsPortProvider = Provider<SocialCredentialsPort>((ref) {
  return const AppleCredentialsAdapter();
});
