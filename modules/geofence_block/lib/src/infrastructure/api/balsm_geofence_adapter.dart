import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repositories/read_denied_countries_repository.dart';

/// SecureStorage key this adapter used before the shared cache tier existed.
///
/// Read never, deleted once. Orphaned keychain entries survive an app
/// uninstall on iOS, so leaving it behind would outlive the app itself.
const _legacyCacheKey = 'balsm.denied_countries_cache';

/// How long a cached deny list is considered fresh.
const _cacheTtl = Duration(hours: 24);

const _geofenceNamespace = 'geofence';
const _denyListKey = 'denied_countries';

/// HTTP adapter implementing [ReadDeniedCountriesRepository] against the Balsm
/// backend (`GET /geofence/denied-countries`).
///
/// Behaviour:
/// - [isDenied] consults the retained list first; on a miss or a stale list it
///   fetches.
/// - Results are retained for 24h in the shared cache tier.
/// - A previously-known block stays enforced when the device is offline. It is
///   NOT kept for a server error — the old implementation used a bare
///   `catch (_)`, which made a 500 or a malformed body indistinguishable from
///   being offline and would silently serve a stale deny list forever.
/// - PHI-free: country codes are not personal health information, so they may
///   be logged and cached.
///
/// Uses the typed [GeofenceApi] from `balsm_api` for transport, matching the
/// convention used by other bounded contexts.
class BalsmGeofenceAdapter implements ReadDeniedCountriesRepository {
  BalsmGeofenceAdapter({
    required GeofenceApi api,
    required CachedValue<List<String>> cache,
    required SecureStorageWrapper legacyStorage,
  })  : _api = api,
        _cache = cache,
        _legacyStorage = legacyStorage;

  final GeofenceApi _api;
  final CachedValue<List<String>> _cache;
  final SecureStorageWrapper _legacyStorage;

  bool _purgedLegacy = false;

  @override
  Future<bool> isDenied(String countryCode) async {
    final normalized = countryCode.trim().toUpperCase();
    if (normalized.isEmpty) return false;
    return (await _deniedCountryCodes()).contains(normalized);
  }

  @override
  Stream<List<String>> watchDeniedCountryCodes() async* {
    yield await _deniedCountryCodes();
  }

  Future<List<String>> _deniedCountryCodes() async {
    await _purgeLegacyCache();
    return await _cache.read(_denyListKey, fetch: _fetch) ?? const <String>[];
  }

  Future<List<String>> _fetch() async {
    final res = await _api.getDeniedCountries();
    return res.deniedCodes.map((e) => e.trim().toUpperCase()).where((e) => e.isNotEmpty).toList(growable: false);
  }

  /// One-shot cleanup of the pre-migration SecureStorage entry.
  Future<void> _purgeLegacyCache() async {
    if (_purgedLegacy) return;
    _purgedLegacy = true;
    try {
      await _legacyStorage.deleteToken(_legacyCacheKey);
    } catch (_) {
      // Keychain unavailable — retrying next launch is fine, and failing to
      // delete a stale country list must never block the geofence check.
    }
  }
}

/// Encodes the deny list for the shared cache tier, which stores JSON objects.
List<String> _decodeCodes(Map<String, dynamic> j) =>
    (j['codes'] as List? ?? const []).map((e) => e.toString()).toList(growable: false);

Map<String, dynamic> _encodeCodes(List<String> codes) => {'codes': codes};

/// Builds a [CachedValue] for the deny list. Exposed so tests can construct the
/// adapter with the same codec the app uses rather than a parallel one.
CachedValue<List<String>> buildDenyListCache(CacheStore store) => CachedValue<List<String>>(
      store: store,
      namespace: _geofenceNamespace,
      ttl: _cacheTtl,
      decode: _decodeCodes,
      encode: _encodeCodes,
    );

/// Riverpod provider exposing the geofence deny-list repository.
final deniedCountriesRepositoryProvider = Provider<ReadDeniedCountriesRepository>((ref) {
  return BalsmGeofenceAdapter(
    api: ref.watch(geofenceApiProvider),
    cache: buildDenyListCache(ref.watch(cacheStoreProvider)),
    legacyStorage: ref.watch(secureStorageProvider),
  );
});
