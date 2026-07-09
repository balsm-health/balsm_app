import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ports/denied_countries_port.dart';

/// Changes the signed-in user's account country.
///
/// Flow:
/// 1. Reject if the target country is geofence-denied (GeofenceFailure).
/// 2. POST /account/country  body: { "countryCode": "<ISO>" }.
/// 3. On success, dispatch [CountryChanged] on the [EventBus].
///
/// RR-001: changing the account country does NOT migrate DOB residency.
/// The DOB row's residency jurisdiction is fixed at creation; only the
/// account's operating country changes here.
class ChangeCountryUseCase {
  ChangeCountryUseCase({
    required AccountApi api,
    required DeniedCountriesPort deniedCountries,
    required EventBus bus,
  })  : _api = api,
        _denied = deniedCountries,
        _bus = bus;

  final AccountApi _api;
  final DeniedCountriesPort _denied;
  final EventBus _bus;

  Future<AppResult<String>> execute({
    required UserId userId,
    required String oldCountry,
    required String newCountry,
  }) async {
    final target = newCountry.trim().toUpperCase();
    if (target.isEmpty) {
      return AppResult.failure(const ValidationFailure('Country is required'));
    }

    if (await _denied.isDenied(target)) {
      return AppResult.failure(const GeofenceFailure());
    }

    try {
      await _api.changeCountry(ChangeCountryRequest(countryCode: target));
      // RR-001: no DOB residency migration is performed.
      _bus.publish(
        CountryChanged(
          userId: userId,
          oldCountry: oldCountry.toUpperCase(),
          newCountry: target,
        ),
      );
      return AppResult.success(target);
    } on ApiException catch (e) {
      return AppResult.failure(switch (e.statusCode) {
        401 || 403 => const UnauthorizedFailure(),
        400 || 422 => const ValidationFailure('Invalid country'),
        _ => const NetworkFailure(),
      });
    }
  }
}

final changeCountryUseCaseProvider = Provider<ChangeCountryUseCase>((ref) {
  return ChangeCountryUseCase(
    api: ref.watch(accountApiProvider),
    deniedCountries: ref.watch(deniedCountriesPortProvider),
    bus: ref.watch(eventBusProvider),
  );
});
