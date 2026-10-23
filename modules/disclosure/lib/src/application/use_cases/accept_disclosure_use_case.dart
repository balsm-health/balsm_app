import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import '../../domain/aggregates/disclosure_acceptance.dart';
import '../../domain/value_objects/ids.dart';
import '../../domain/events/disclosure_accepted.dart';
import '../../infrastructure/drift/disclosure_dao.dart';

/// Orchestrates the disclosure acceptance flow:
/// 1. Persists on-device via [DisclosureDao].
/// 2. Syncs to cloud via `POST /disclosure/accept`.
/// 3. Publishes [DisclosureAccepted] on the [EventBus].
class AcceptDisclosureUseCase {
  AcceptDisclosureUseCase({
    required DisclosureDao dao,
    required DisclosureApi api,
    required EventBus eventBus,
  })  : _dao = dao,
        _api = api,
        _eventBus = eventBus;

  final DisclosureDao _dao;
  final DisclosureApi _api;
  final EventBus _eventBus;

  Future<AppResult<void>> execute({
    required DisclosureId disclosureId,
    required String version,
    required String countryCode,
    required String supervisoryAuthority,
    required String preferredLanguage,
  }) async {
    final acceptance = DisclosureAcceptance(
      disclosureId: disclosureId,
      version: version,
      countryCodeAtAccept: countryCode,
      supervisoryAuthorityNameAtAccept: supervisoryAuthority,
      preferredLanguageAtAccept: preferredLanguage,
      acceptedAt: DateTime.now().toUtc(),
    );

    // Step 1: persist on-device.
    try {
      await _dao.insert(acceptance);
    } catch (e) {
      return AppResult.failure(
        StorageFailure('Failed to persist disclosure acceptance: $e'),
      );
    }

    // Step 2: sync to cloud (best-effort; offline tolerance).
    try {
      await _api.accept(AcceptDisclosureRequest(
        disclosureId: disclosureId.value,
        version: version,
        countryCode: countryCode,
        supervisoryAuthority: supervisoryAuthority,
        preferredLanguage: preferredLanguage,
      ));
    } catch (_) {
      // Cloud sync is best-effort; offline is tolerated.
      // A background retry queue will pick this up (Phase 4).
    }

    // Step 3: publish domain event.
    _eventBus.publish(
      DisclosureAccepted(
        disclosureId: disclosureId,
        version: version,
        countryCode: countryCode,
        supervisoryAuthority: supervisoryAuthority,
        preferredLanguage: preferredLanguage,
        acceptedAt: acceptance.acceptedAt,
      ),
    );

    return AppResult.success(null);
  }

  /// Re-sends an acceptance recorded while the account had no server session
  /// (device-only). Best-effort, like step 2 of [execute]. Never throws.
  Future<bool> resync({required DisclosureId disclosureId, required String version}) async {
    try {
      final a = await _dao.watchAcceptance(disclosureId, version).first;
      if (a == null) return false;
      await _api.accept(AcceptDisclosureRequest(
        disclosureId: a.disclosureId.value,
        version: a.version,
        countryCode: a.countryCodeAtAccept,
        supervisoryAuthority: a.supervisoryAuthorityNameAtAccept,
        preferredLanguage: a.preferredLanguageAtAccept,
      ));
      return true;
    } catch (_) {
      return false;
    }
  }
}
