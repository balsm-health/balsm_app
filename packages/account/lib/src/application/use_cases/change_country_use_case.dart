import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/events/country_changed.dart';
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
    required Dio dio,
    required DeniedCountriesPort deniedCountries,
    required EventBus bus,
  })  : _dio = dio,
        _denied = deniedCountries,
        _bus = bus;

  final Dio _dio;
  final DeniedCountriesPort _denied;
  final EventBus _bus;

  Future<AppResult<String>> execute({
    required String userId,
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
      await _dio.post<Map<String, dynamic>>(
        '/account/country',
        data: {'countryCode': target},
      );
      // RR-001: no DOB residency migration is performed.
      _bus.publish(
        CountryChanged(
          userId: userId,
          oldCountry: oldCountry.toUpperCase(),
          newCountry: target,
        ),
      );
      return AppResult.success(target);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        return AppResult.failure(const UnauthorizedFailure());
      }
      if (status == 400 || status == 422) {
        return AppResult.failure(const ValidationFailure('Invalid country'));
      }
      return AppResult.failure(const NetworkFailure());
    }
  }
}

final changeCountryUseCaseProvider = Provider<ChangeCountryUseCase>((ref) {
  return ChangeCountryUseCase(
    dio: ref.watch(dioClientProvider),
    deniedCountries: ref.watch(deniedCountriesPortProvider),
    bus: ref.watch(eventBusProvider),
  );
});
