import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/ports/card_sealer.dart';
import '../application/ports/device_key_store.dart';
import '../application/ports/link_local_store.dart';
import '../application/ports/own_emergency_card_reader.dart';
import '../application/use_cases/end_family_link_use_case.dart';
import '../application/use_cases/read_shared_card_use_case.dart';
import '../application/use_cases/refresh_family_links_use_case.dart';
import '../application/use_cases/request_family_link_use_case.dart';
import '../application/use_cases/respond_to_family_link_use_case.dart';
import '../application/use_cases/set_card_sharing_use_case.dart';
import '../domain/entities/family_link.dart';
import '../domain/value_objects/emergency_card_payload.dart';
import '../domain/value_objects/link_relation.dart';
import '../infrastructure/crypto/ecies_card_sealer.dart';
import '../infrastructure/secure/secure_device_key_store.dart';
import '../infrastructure/secure/secure_link_local_store.dart';

/// The account holder's own emergency card. Bound by the app shell in
/// bootstrap() — the profile and account modules own the data. Unbound, no
/// card can be read, so none is ever sealed: sharing fails closed.
final ownEmergencyCardReaderProvider = Provider<OwnEmergencyCardReader>((ref) => const _NoCard());

class _NoCard implements OwnEmergencyCardReader {
  const _NoCard();
  @override
  Future<EmergencyCardPayload?> read() async => null;
}

final cardSealerProvider = Provider<CardSealer>((ref) => EciesCardSealer());

/// This phone's key pair for the signed-in account.
final deviceKeyStoreProvider = Provider<DeviceKeyStore>(
  (ref) => SecureDeviceKeyStore(
    storage: ref.watch(secureStorageProvider),
    accountId: ref.watch(currentUserIdProvider)?.value ?? 'signed-out',
  ),
);

final linkLocalStoreProvider = Provider<LinkLocalStore>(
  (ref) => SecureLinkLocalStore(
    storage: ref.watch(secureStorageProvider),
    accountId: ref.watch(currentUserIdProvider)?.value ?? 'signed-out',
  ),
);

final setCardSharingUseCaseProvider = Provider<SetCardSharingUseCase>(
  (ref) => SetCardSharingUseCase(
    api: ref.watch(familyLinksApiProvider),
    sealer: ref.watch(cardSealerProvider),
    local: ref.watch(linkLocalStoreProvider),
    card: ref.watch(ownEmergencyCardReaderProvider),
    ownerAccountId: () => ref.read(currentUserIdProvider)?.value,
  ),
);

final refreshFamilyLinksUseCaseProvider = Provider<RefreshFamilyLinksUseCase>(
  (ref) => RefreshFamilyLinksUseCase(
    api: ref.watch(familyLinksApiProvider),
    keys: ref.watch(deviceKeyStoreProvider),
    local: ref.watch(linkLocalStoreProvider),
    sharing: ref.watch(setCardSharingUseCaseProvider),
  ),
);

final requestFamilyLinkUseCaseProvider = Provider<RequestFamilyLinkUseCase>(
  (ref) => RequestFamilyLinkUseCase(
    api: ref.watch(familyLinksApiProvider),
    keys: ref.watch(deviceKeyStoreProvider),
    local: ref.watch(linkLocalStoreProvider),
  ),
);

final respondToFamilyLinkUseCaseProvider = Provider<RespondToFamilyLinkUseCase>(
  (ref) => RespondToFamilyLinkUseCase(
    api: ref.watch(familyLinksApiProvider),
    keys: ref.watch(deviceKeyStoreProvider),
    local: ref.watch(linkLocalStoreProvider),
  ),
);

final endFamilyLinkUseCaseProvider = Provider<EndFamilyLinkUseCase>(
  (ref) => EndFamilyLinkUseCase(api: ref.watch(familyLinksApiProvider), local: ref.watch(linkLocalStoreProvider)),
);

final readSharedCardUseCaseProvider = Provider<ReadSharedCardUseCase>(
  (ref) => ReadSharedCardUseCase(
    api: ref.watch(familyLinksApiProvider),
    sealer: ref.watch(cardSealerProvider),
    keys: ref.watch(deviceKeyStoreProvider),
  ),
);

/// The signed-in account's links, both directions. Pulled when first read and
/// again on [FamilyLinksNotifier.refresh]; a failed pull keeps what was last
/// shown (empty before the first success) rather than blanking the list.
final familyLinksProvider = AsyncNotifierProvider<FamilyLinksNotifier, FamilyLinks>(FamilyLinksNotifier.new);

class FamilyLinksNotifier extends AsyncNotifier<FamilyLinks> {
  @override
  Future<FamilyLinks> build() async {
    if (ref.watch(currentUserIdProvider) == null) return FamilyLinks.empty;
    return _pull(FamilyLinks.empty);
  }

  Future<FamilyLinks> _pull(FamilyLinks fallback) async {
    final result = await ref.read(refreshFamilyLinksUseCaseProvider)();
    return result.fold((links) => links, (_) => fallback);
  }

  /// Pulls both lists again — app start/resume, the Family screen, pull-to-refresh.
  Future<void> refresh() async {
    if (ref.read(currentUserIdProvider) == null) return;
    final previous = state.valueOrNull ?? FamilyLinks.empty;
    state = AsyncData(await _pull(previous));
  }

  Future<AppResult<String>> request({required String jti, required LinkRelation relation, ScannedIdentity? scanned}) =>
      _then(ref.read(requestFamilyLinkUseCaseProvider)(jti: jti, relation: relation, scanned: scanned));

  Future<AppResult<void>> approve(String linkId) => _then(ref.read(respondToFamilyLinkUseCaseProvider).approve(linkId));

  Future<AppResult<void>> decline(String linkId) => _then(ref.read(respondToFamilyLinkUseCaseProvider).decline(linkId));

  Future<AppResult<void>> cancel(String linkId) => _then(ref.read(endFamilyLinkUseCaseProvider).cancel(linkId));

  Future<AppResult<void>> unlink(String linkId) => _then(ref.read(endFamilyLinkUseCaseProvider).unlink(linkId));

  Future<AppResult<void>> setCardSharing(FamilyLink link, {required bool on}) =>
      _then(ref.read(setCardSharingUseCaseProvider)(link, on: on));

  /// Every change is followed by a pull, so the lists show the server's word.
  Future<AppResult<T>> _then<T>(Future<AppResult<T>> action) async {
    final result = await action;
    await refresh();
    return result;
  }
}

/// The card the other party shares over link [linkId], opened on this phone.
/// Success with null when none is shared.
final sharedCardProvider = FutureProvider.autoDispose.family<AppResult<SharedCard?>, String>((ref, linkId) async {
  final link = ref.watch(familyLinksProvider).valueOrNull?.byId(linkId);
  if (link == null) return AppResult.success(null);
  return ref.read(readSharedCardUseCaseProvider)(link);
});
