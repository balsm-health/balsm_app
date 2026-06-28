import 'package:core/core.dart';
import '../../domain/aggregates/disclosure_acceptance.dart';
import '../../domain/events/disclosure_accepted.dart';
import '../../infrastructure/drift/disclosure_dao.dart';

/// Orchestrates the disclosure acceptance flow:
/// 1. Persists on-device via [DisclosureDao].
/// 2. Syncs to cloud via `POST /disclosure/accept`.
/// 3. Publishes [DisclosureAccepted] on the [EventBus].
class AcceptDisclosureUseCase {
  AcceptDisclosureUseCase({
    required DisclosureDao dao,
    required BalsmApiClient apiClient,
    required EventBus eventBus,
  })  : _dao = dao,
        _apiClient = apiClient,
        _eventBus = eventBus;

  final DisclosureDao _dao;
  final BalsmApiClient _apiClient;
  final EventBus _eventBus;

  Future<AppResult<void>> execute({
    required String disclosureId,
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
      await _apiClient.dio.post<void>(
        '/disclosure/accept',
        data: {
          'disclosure_id': disclosureId,
          'version': version,
          'country_code': countryCode,
          'supervisory_authority': supervisoryAuthority,
          'preferred_language': preferredLanguage,
        },
      );
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
}
