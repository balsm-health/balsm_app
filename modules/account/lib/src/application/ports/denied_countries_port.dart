import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Local port mirroring `geofence_block`'s denied-countries repository.
///
/// The `geofence_block` package owns the canonical implementation
/// (`deniedCountriesRepositoryProvider`). To keep the `account` package
/// independently compilable while that package is finalised by another
/// agent, we expose a local provider with a permissive default and let the
/// app shell override it with the real geofence-backed repository, e.g.:
///
/// ```dart
/// deniedCountriesPortProvider.overrideWith(
///   (ref) => GeofenceDeniedCountriesPort(
///     ref.watch(geofence_block.deniedCountriesRepositoryProvider),
///   ),
/// );
/// ```
abstract interface class DeniedCountriesPort {
  /// True if onboarding / residency to [countryCode] is geofence-blocked.
  Future<bool> isDenied(String countryCode);
}

/// Default: nothing is denied. Overridden by the app shell with the real
/// `geofence_block` implementation.
class _AllowAllDeniedCountriesPort implements DeniedCountriesPort {
  const _AllowAllDeniedCountriesPort();
  @override
  Future<bool> isDenied(String countryCode) async => false;
}

final deniedCountriesPortProvider = Provider<DeniedCountriesPort>(
  (ref) => const _AllowAllDeniedCountriesPort(),
);
